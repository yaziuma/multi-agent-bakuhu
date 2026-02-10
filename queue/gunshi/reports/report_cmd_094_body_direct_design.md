最初に、今回の深掘りタスクは設計のやりがいがあってワクワクします。コンテキスト読み込み完了（`.claude/rules/`一式と`.claude/docs/DESIGN.md`確認済み）で、この内容に沿って進めます。

**前提確認（読み込み済み）**
`docs/benchmark_heavy_timeout_analysis_ja.md`  
`pyprolog/runtime/logic_interpreter.py`  
`pyprolog/runtime/interpreter.py`  
`pyprolog/runtime/execution_frames.py`  

---

**1. COMPLETE RECURSION PATH MAPPING（全再帰経路 + 行番号）**

**A. `_execute_body_direct` 内の直接再帰**
1. Disjunction `;/2`  
`pyprolog/runtime/logic_interpreter.py:1006-1015`  
`_execute_body_direct` → `_execute_body_direct`（左枝/右枝）
2. Negation `\+/1`  
`pyprolog/runtime/logic_interpreter.py:1018-1026`  
`_execute_body_direct` → `_execute_body_direct`（内側ゴール）

**B. `_execute_body_direct` → `_execute_conjunction_iterative` → `_execute_body_direct`**
1. Conjunction `,/2`  
`pyprolog/runtime/logic_interpreter.py:1000-1002`  
`_execute_body_direct` → `_execute_conjunction_iterative`
2. Iterative conjunction 内で再帰呼び出し  
`pyprolog/runtime/logic_interpreter.py:1140` / `1168`  
`_execute_conjunction_iterative` → `_execute_body_direct`

**C. `_execute_body_direct` → `_execute_single_goal` → `solve_goal_direct` → `_execute_body_direct`**
1. Atomic goal 実行  
`pyprolog/runtime/logic_interpreter.py:1036-1037`  
`_execute_body_direct` → `runtime._execute_single_goal`
2. `_execute_single_goal` が `solve_goal_direct` を呼ぶ  
`pyprolog/runtime/interpreter.py:610-615`（Atom）  
`pyprolog/runtime/interpreter.py:870-875`（Term）
3. ルール本体の実行で再び `_execute_body_direct`  
`pyprolog/runtime/logic_interpreter.py:934-936`  
`pyprolog/runtime/logic_interpreter.py:955-958`

**D. `_execute_body_direct` → `_execute_single_goal` → `->/2` → `execute()` → … → `_execute_body_direct`**
1. Control evaluator `->/2` 内で `self.execute` を再帰呼び出し  
`pyprolog/runtime/interpreter.py:392-396`  
`_execute_single_goal` → control evaluator → `execute(condition)` / `execute(then_part)`
2. `execute()` が非 iterative の場合、内部で `solve_goal_direct` → `_execute_body_direct` に到達  
`pyprolog/runtime/interpreter.py:483-521` と `logic_interpreter.py:934-958`

**E. 既存フレーム実装にも再帰が残る（将来統合時の罠）**
1. `BodyFrame` が `_execute_body_direct` / `_execute_conjunction_recursive` を呼んでいる  
`pyprolog/runtime/execution_frames.py:400-473`（BodyFrame）  
`pyprolog/runtime/execution_frames.py:341-361`（ConjunctionFrame）  
ここも再帰温床（設計上の修正対象）

---

**2. FULL ITERATIVE DESIGN（再帰排除の設計方針）**

**基本方針**
- `_execute_body_direct` を「専用の反復実行ループ」に置換する。  
- ルール本体の評価は **フレーム駆動** で行い、呼び出し深さは固定。  
- `CutException` は「フレーム/選択点の明示管理」で表現する。  

**新/改修フレーム（提案）**
1. `DisjunctionFrame`（新規）
   - 状態: `state=initial|left|right|done`, `left_iter`, `right_iter`
   - 左枝を使い切ったら右枝へ切替
   - Cut が入ったら右枝へ進まず終了
2. `NegationFrame`（既存だが body 用に再設計）
   - `entry_stack_depth`, `entry_choice_depth` を保持して Cut バリアを作る
   - 内側ゴールが1回でも成功したら negation失敗
   - 内側で Cut が起きても外へ出ない（現在の仕様維持）
3. `IfThenFrame` / `IfThenElseFrame`（新規）
   - `->/2` を単独で処理するための `IfThenFrame`
   - `->/2` + `;/2` 結合を `IfThenElseFrame` で扱う  
   - 条件が一度成功したら then を実行し、else を破棄（Cut相当）
4. `ConjunctionFrame`（既存だが body-iterative に改修）
   - `goal_stack` でバックトラック  
   - 各 goal の実行は `BodyExecutionState` から得られる iterator  
5. `GoalFrame`（既存）
   - Atomic goal を `_execute_single_goal` で評価

**反復実行ループ（新設例: `_execute_body_direct_iterative`）**
- `stack: list[Frame]` と `choice_points: list[ChoicePoint]` を持つ
- `push_body(goal, env)` が論理演算子を判別し、適切な Frame を積む
- `while stack:` で frame を step 実行、`yield env` で解を返す
- `CutException` は `cut_barrier` までの ChoicePoint を破棄し、上位へ伝播

---

**3. RECURSIVE CALL SITE → ITERATIVE REPLACEMENT（具体設計）**

**A. Disjunction (`;/2`)**
現在のコード（`pyprolog/runtime/logic_interpreter.py:1006-1015`）:
```python
if functor_name == ";" and len(body.args) == 2:
    left_goal, right_goal = body.args[0], body.args[1]
    try:
        yield from self._execute_body_direct(left_goal, env)
    except CutException:
        raise
    yield from self._execute_body_direct(right_goal, env)
    return
```
提案:
```python
# 反復実行ループ内で DisjunctionFrame を push
stack.append(DisjunctionFrame(env=env, left=left_goal, right=right_goal))
```
状態管理:
- `DisjunctionFrame` が `left` の iterator を消費、尽きたら `right` に切替
- `CutException` 発生時は `right` を破棄して上位へ伝播

**B. Negation (`\+/1`)**
現在のコード（`pyprolog/runtime/logic_interpreter.py:1018-1033`）:
```python
for _ in self._execute_body_direct(inner_goal, env):
    solution_found = True
    break
...
if not solution_found:
    yield env
```
提案:
```python
stack.append(NegationFrame(env=env, inner_goal=inner_goal,
                           entry_stack_depth=len(stack),
                           entry_choice_depth=len(choice_points)))
```
状態管理:
- 内側で1解でも出れば `inner_succeeded=True`
- 成功時は negation 失敗（何も yield しない）
- 内側 Cut は negation 内で止める（現仕様維持）

**C. Conjunction (`,/2`)**
現在のコード（`pyprolog/runtime/logic_interpreter.py:1000-1002`）:
```python
goals = self._flatten_conjunction_iterative(body)
yield from self._execute_conjunction_iterative(goals, env)
return
```
提案:
```python
goals = self._flatten_conjunction_iterative(body)
stack.append(ConjunctionFrame(env=env, goals=goals))
```
状態管理:
- `ConjunctionFrame` が `goal_stack` を持つ
- 各 goal は `BodyExecutionState` の iterator を使い、再帰せず進行

**D. Atomic Goal**
現在のコード（`pyprolog/runtime/logic_interpreter.py:1036-1037`）:
```python
yield from self.runtime._execute_single_goal(body, env)
```
提案:
```python
stack.append(GoalFrame(env=env, goal=body))
```
状態管理:
- `GoalFrame` が `self.runtime._execute_single_goal` の iterator を保持

**E. `solve_goal_direct` 内の `_execute_body_direct` 呼び出し**
現在のコード（`pyprolog/runtime/logic_interpreter.py:934-958`）:
```python
yield from self._execute_body_direct(rule_body, new_env)
```
提案:
```python
yield from self._execute_body_direct_iterative(rule_body, new_env)
```
状態管理:
- ルール本体は必ず反復実行ループへ

**F. `->/2`（if-then）**
現在のコード（`pyprolog/runtime/interpreter.py:392-396`）:
```python
for cond_env in self.execute(condition, env):
    for then_env_solution in self.execute(then_part, cond_env):
        yield then_env_solution
```
提案:
- `_execute_single_goal` の `->` ハンドラを **body-iterative 経由にする**
- `IfThenFrame` が `condition` の最初の成功で `then` を実行し、それ以降の condition 解や else を切る

---

**4. `_execute_conjunction_iterative` の統合方針**

現状の問題:
- `_execute_conjunction_iterative` が `_execute_body_direct` を呼び続ける（`logic_interpreter.py:1140, 1168`）

統合案:
1. `_execute_conjunction_iterative` を内部ユーティリティ化し、外部は使わない
2. すべて `ConjunctionFrame` + `_execute_body_direct_iterative` で統一
3. `_execute_body_direct_iterative` 内で `ConjunctionFrame` を積むため、相互呼び出しは不要

---

**5. TEST PLAN（検証方針）**

**既存テスト**
1. `tests/benchmark/test_benchmarks.py::test_nrev_heavy`
2. `tests/benchmark/test_benchmarks.py::test_primes_heavy`
3. `tests/benchmark/test_benchmarks.py::test_recursion_depth_heavy`

**追加すべきテスト**
1. `cut` の枝刈り  
`(a ; !, b)` が `b` を通らない
2. negation + cut  
`\+ (goal, !)` の振る舞いが現行と一致
3. if-then / if-then-else  
`(Cond -> Then ; Else)` が Cond 成功時に Else を捨てる
4. 深い conjunction + disjunction の混在  
スタック深さが増えず正常探索

**期待される挙動変化**
- RecursionError を起こさず `heavy` が正しく解を返す
- 解の順序は基本維持されるが、内部実装変更でわずかな順序差が生じる可能性

---

**6. RISK ANALYSIS（破綻しやすい点）**

1. **Cut のスコープ管理ミス**  
`DisjunctionFrame` や `IfThenElseFrame` の cut バリアが正しくないと探索が過剰に刈られる
2. **Negation の束縛漏れ**  
内側で束縛した env を外側に漏らさない保証が必要
3. **`->/2` + `;/2` の結合優先度**  
パース結果と実装が一致しないと if-then-else が誤作動
4. **トレーサー/統計情報**  
`_execute_single_goal` 経由の挙動は維持されるが、実行経路の変更でログ順序が変わる可能性
5. **既存 `execution_frames.py` の再帰呼び出し残存**  
BodyFrame/ConjunctionFrame 内部の `_execute_body_direct` 依存を確実に排除する必要

---

必要なら、この設計を「具体コード差分案」まで落とした叩き台も用意します。次の一手として、どこまで具体化しましょうか。

1. 反復実行ループの疑似コードをさらに詳細化  
2. `execution_frames.py` の改修案（具体API/Frame仕様）  
3. テストケースの具体例（Prologコード付き）
