面白いフェーズ2の回帰分析ですね、コードを読んだうえで体系的に整理しました。  
まず前提として、指定された以下のファイルがこのリポジトリ内に見当たらず、テスト失敗138件の**正確な内訳**は推定になっています。  
不足しているファイル:
- `/home/quieter/projects/pyprolog/queue/reports/ashigaru1_report.yaml`
- `/home/quieter/projects/pyprolog/queue/reports/ashigaru2_report.yaml`  
代替として参照したのは `/home/quieter/projects/multi-agent-bakuhu/queue/shinobi/reports/report_cmd_096_regression_patterns.md` です。

**ROOT CAUSE CATEGORIZATION（推定）**  
根拠: `pyprolog/runtime/execution_frames.py`, `pyprolog/runtime/logic_interpreter.py`, `pyprolog/runtime/interpreter.py` と回帰パターンレポート

- (A) `execute_iterative()` が PushFrame/YieldEnv を完全に扱えていない  
推定: 55〜70件  
理由: `execute_iterative()` の「Other frame types」分岐が `PushFrame` を正しく処理しない。`NegationFrame` の実装と `execute_iterative()` 側の期待フィールドが不一致。`ExecutionState.push_goal()` は `NegationFrame` に未定義フィールドを渡している。  
影響: `\+`, `;`, `,` を含むゴール、複合目標の解決、トップレベルの制御フロー全般。

- (B) findall/bagof/setof の実行経路が旧API前提  
推定: 5〜15件  
理由: `findall/3` は `runtime.execute()` を呼ぶが、フレーム駆動化後の `PushFrame`/`YieldEnv` 的な状態管理を前提にしない設計。`bagof/3` や `setof/3` は未実装の可能性が高く、失敗テストが固定数出る。  

- (C) GoalFrame 系ステートマシンの不整合  
推定: 25〜35件  
理由: `GoalFrame.step()` と `execute_iterative()` の相互作用が曖昧で、子フレームの進行/完了状態の引き渡しが弱い。`StopIteration` の扱いが「親フレームへの復帰」に十分反映されない。  
影響: 再帰・多解探索・深い連鎖での無限ループ/欠落解。

- (D) CutException の伝播/選択肢消去が不完全  
推定: 20〜30件  
理由: `ExecutionState.cut_barrier` は初期値固定で、節ごとのカット境界が更新されない。`NegationFrame` の cut バリア仕様と `execute_iterative()` が一致していない。  
影響: `!`, `->/2`, `\+/1`, disjunction, if-then のテスト。

- (E) BindingEnvironment の共有/コピー不整合  
推定: 10〜20件  
理由: disjunction の右枝でのみ `env.copy()` を使うなど、枝間の状態隔離が不均一。`GoalSeqFrame` が `interpreter.execute()` でネスト実行し、環境寿命の境界が曖昧。  
影響: バックトラックや部分的な束縛の漏れ。

- (F) 旧APIが残る実行経路  
推定: 5〜10件  
理由: `logic_interpreter._execute_body_direct()` と `_execute_body_iterative()` が混在している。`NegationFrame` が内部で `_execute_body_iterative()` を直接呼ぶなど、異なる実行モデルが並存。  

---

**FIX PRIORITY MATRIX（推定）**

- (A)  
影響数: 55〜70  
複雑度: 複雑  
リスク: 高  
依存: 最優先。これが崩れていると他の修正検証が不安定。

- (C)  
影響数: 25〜35  
複雑度: 中  
リスク: 中  
依存: (A) の後。フレーム状態管理を確定させてから修正。

- (D)  
影響数: 20〜30  
複雑度: 中〜複雑  
リスク: 高  
依存: (A)(C) の後。フレーム/choicepoint が安定してから。

- (E)  
影響数: 10〜20  
複雑度: 中  
リスク: 中  
依存: (A)(C) の後。コピー/共有設計の整理が必要。

- (B)  
影響数: 5〜15  
複雑度: 中  
リスク: 中  
依存: (A) の後。メタ述語は基盤の実行器が安定してから。

- (F)  
影響数: 5〜10  
複雑度: 低〜中  
リスク: 低  
依存: (A) の後。経路統一が必要。

---

**SYSTEMATIC FIX PLAN（段階的・検証付き）**

**Phase 0: 可観測性と差分基準の確立**  
目的: 回帰の見え方を固定し、修正後の回帰を最小化。  
手順:  
1. 旧実装と新実装の出力比較の差分テストを追加する。  
2. `execute_iterative()` のフレーム遷移ログを軽量化して追加する。  
検証: `pytest --collect-only` と `pytest -k "operator or cut or disjunction"` を最小セットで確認。

**Phase 1: 実行ループ基盤の修正 (A/C/F)**  
修正ポイント:  
1. `execute_iterative()` の「Other frame types」分岐を削除し、`PushFrame`/`YieldEnv` を必ず処理する。  
2. `NegationFrame` の実装と `execute_iterative()` の期待フィールドを一致させる。  
3. `ExecutionState.push_goal()` で `NegationFrame` に渡している未定義フィールドを解消する。  
4. `DisjunctionFrame` を使わない設計なら `LogicInterpreter._make_frame()` から `DisjunctionFrame` を排除する。逆に使うなら `execute_iterative()` に明示分岐を追加する。  
検証:  
- `\+`, `;`, `,` の基本テスト  
- 再帰系小テスト（`member/2`, `append/3` の多解探索）

**Phase 2: カットと選択点の正規化 (D/E)**  
修正ポイント:  
1. `cut_barrier` を「各呼び出しレベルで設定」できるようにする。  
2. `ChoicePoint` を節単位で作成し、`CutException` で適切に破棄する。  
3. `GoalSeqFrame` で `execute()` を呼ぶ設計を見直し、必要なら「同一スタック内のサブフレーム」に統合する。  
検証:  
- `!/0`, `->/2`, `\+/1` のカット境界テスト  
- disjunction の左枝 cut による右枝消去テスト

**Phase 3: メタ述語のフレーム対応 (B)**  
修正ポイント:  
1. `findall/3` を PushFrame/YieldEnv 対応にする。  
2. `bagof/3`, `setof/3` を未実装なら最小仕様で追加。  
検証:  
- `findall/3` の「失敗→空リスト」「成功→順序保持」  
- `bagof/3` の自由変数処理、`setof/3` のソート・重複排除

**Phase 4: 実行経路の統一と不要経路の削除 (F)**  
修正ポイント:  
1. `_execute_body_direct()` と `_execute_body_iterative()` の役割を統合。  
2. `solve_goal_direct()` と `_solve_goal_for_frame()` の責務を整理。  
検証:  
- 旧実装との差分テストで 0 diff を目標。

---

**tak_light HANG ANALYSIS（推定）**

tak/4 は「比較 → 算術 → 3回の再帰 → 最終再帰」という深い連鎖です。  
現在のフレーム駆動系は以下の弱点が重なり、無限ループに入りやすい構造です。

実行経路の要点:
1. `execute_iterative()` → `GoalFrame` が `tak/4` の節を探索  
2. 節ボディは `,` 連鎖なので `ExecutionState.push_goal()` が `GoalSeqFrame` を生成  
3. `GoalSeqFrame.step()` は各ゴールを `interpreter.execute()` でネスト実行  
4. ネストされた `execute_iterative()` は独立した `ExecutionState` を持つため、親フレームと状態共有がない  
5. 結果として、子ゴールが失敗したときに「親の GoalFrame が次の節へ進む」タイミングと「GoalSeqFrame の内部 iterator の再開」がズレる

具体的に無限ループ化しやすい箇所:
- `GoalSeqFrame.step()` は `interpreter.execute()` の generator を保持し続ける  
- その generator が内部で `GoalFrame` の状態遷移を正しく解放できない場合、同じ節の同じ条件を再評価し続ける  
- `tak/4` は再帰深度が高く、同一パターンが繰り返されるため、この「状態遷移の不整合」が hang として顕在化する

対策の方向性:
- `GoalSeqFrame` が `interpreter.execute()` に依存する設計をやめ、同一フレームスタック内で連結実行する  
- 親フレームが「子ゴールの成功/失敗」を確実に受け取り、節の探索位置を進める仕組みにする  

---

**152 MISSING TESTS ANALYSIS（推定）**

総数が 624 → 472 に減っているのは、以下のいずれかが濃厚です。

- テスト収集時の ImportError によりファイル単位で落ちている  
- `-k` や `-m` 等のフィルタが CI 側に残っている  
- `pytest` が途中ハングで停止し、残りが計上されていない  
- 以前は `xfail`/`skip` されていたが、今は「収集されない」扱いになっている

回復手順（推奨）:
1. `pytest --collect-only -q` で収集数を確認  
2. `pytest -ra` で skip / xfail / xpass を一覧化  
3. 失敗時の `ImportError` を解消し、対象ファイルを復帰  
4. ハングがある場合は `-k tak_light` を単体で切り出して原因特定

---

必要なら、次に「Phase 1 の具体的コード修正案」まで一気に詰めるので、続けるか教えてください。  
次の進め方はどれが良いですか。  
1. Phase 1 の修正方針をコード単位で具体化  
2. tak_light の hang を実際の最小ケースで分解  
3. テスト収集数の減少を最小手順で診断
