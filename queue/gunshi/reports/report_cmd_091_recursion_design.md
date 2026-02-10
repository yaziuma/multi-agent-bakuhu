いいテーマですね、プロジェクトのルールと`DESIGN.md`は読み込み済みで、これから結果を整理します。

**再帰呼び出し一覧（全件）**  
注: 行番号は`nl -ba`基準。再帰パターンは`direct`（自己呼出）、`mutual`（相互）、`tail`（末尾近傍）で記載。

**CLI**
| ファイル | 関数 | 行 | 再帰パターン | 備考 |
| --- | --- | --- | --- | --- |
| `pyprolog/cli/interactive_repl.py` | `InteractiveProlog._format_term_for_display` | 520 | direct | Term引数の再帰 |
| `pyprolog/cli/interactive_repl.py` | `InteractiveProlog._format_term_for_display` | 558 | direct | Pythonリスト要素の再帰 |
| `pyprolog/cli/interactive_repl.py` | `InteractiveProlog._format_term_for_display` | 574 | direct | `'.'/2`リスト要素の再帰 |
| `pyprolog/cli/interactive_repl.py` | `InteractiveProlog._format_term_for_display` | 581 | direct | 不完全リスト末尾の再帰 |
| `pyprolog/cli/simple_interactive.py` | `SimplePrologInteractive._format_term_for_display` | 219 | direct | Term引数の再帰 |
| `pyprolog/cli/simple_interactive.py` | `SimplePrologInteractive._format_term_for_display` | 251 | direct | `'.'/2`リスト要素の再帰 |
| `pyprolog/cli/simple_interactive.py` | `SimplePrologInteractive._format_term_for_display` | 258 | direct | 不完全リスト末尾の再帰 |
| `pyprolog/cli/simple_interactive.py` | `SimplePrologInteractive._format_term_for_display` | 265 | direct | Pythonリスト要素の再帰 |

**Core / Parser**
| ファイル | 関数 | 行 | 再帰パターン | 備考 |
| --- | --- | --- | --- | --- |
| `pyprolog/core/binding_environment.py` | `BindingEnvironment.get_value` | 59 | direct (tail) | 親環境チェーンの再帰 |
| `pyprolog/core/binding_environment.py` | `BindingEnvironment.merge_with` | 111 | direct | 親環境チェーンの再帰 |
| `pyprolog/core/binding_environment.py` | `BindingEnvironment.to_dict` | 129 | direct | 親環境チェーンの再帰 |
| `pyprolog/core/types.py` | `ListTerm.to_internal_list_term` | 109 | direct | tailがListTermの場合 |
| `pyprolog/parser/parser.py` | `Parser._parse_expression_with_precedence` | 257 | direct | 前置演算子の再帰 |
| `pyprolog/parser/parser.py` | `Parser._parse_expression_with_precedence` | 294 | direct | 右辺解析の再帰 |
| `pyprolog/parser/parser.py` | `Parser._parse_primary` | 340 | mutual | `_parse_expression_with_precedence`との相互再帰 |
| `pyprolog/parser/parser.py` | `Parser._parse_list` | 399 | mutual | `_parse_expression_with_precedence`との相互再帰 |
| `pyprolog/parser/parser.py` | `Parser._parse_list` | 412 | mutual | `_parse_expression_with_precedence`との相互再帰 |

**Runtime（実行系）**
| ファイル | 関数 | 行 | 再帰パターン | 備考 |
| --- | --- | --- | --- | --- |
| `pyprolog/runtime/builtins.py` | `AppendPredicate.execute` | 640 | direct (tail-ish) | `append/3`の自己呼び出し |
| `pyprolog/runtime/execution_frames.py` | `ExecutionState._flatten_conjunction` | 403 | direct | 左側展開 |
| `pyprolog/runtime/execution_frames.py` | `ExecutionState._flatten_conjunction` | 404 | direct | 右側展開 |
| `pyprolog/runtime/interpreter.py` | `Runtime._extract_functors_from_term` | 117 | direct | Term引数の再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._extract_functors_from_term` | 124 | direct | list要素の再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._execute_goal_sequence` | 257 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._execute_goal_sequence` | 274 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._create_logical_evaluator`(evaluator) | 293 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._create_logical_evaluator`(evaluator) | 301 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._create_logical_evaluator`(evaluator) | 309 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._create_control_evaluator`(evaluator) | 392 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._create_control_evaluator`(evaluator) | 395 | mutual | `execute`との相互再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._convert_vars_to_japanese` | 1242 | direct | Term引数の再帰 |
| `pyprolog/runtime/interpreter.py` | `Runtime._convert_vars_to_japanese` | 1264 | direct | list要素の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter.deep_dereference_term` | 562 | direct | Term引数の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter.deep_dereference_term` | 574 | direct | ListTerm要素の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter.deep_dereference_term` | 578 | direct | ListTerm tailの再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter._execute_body_direct` | 1010 | direct | 左枝の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter._execute_body_direct` | 1015 | direct | 右枝の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter._execute_body_direct` | 1024 | direct | 否定内の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter._execute_conjunction_recursive` | 1104 | direct | 連言の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter.instantiate_term`内`_substitute_vars_in_copy` | 1148 | direct | 変数代入の再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter.solve_goal` | 736 | mutual | `Runtime.execute`との相互再帰 |
| `pyprolog/runtime/logic_interpreter.py` | `LogicInterpreter.solve_goal` | 758 | mutual | `Runtime.execute`との相互再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter.evaluate` | 30 | direct | Variable解決の再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter.evaluate` | 48 | direct | 左項評価の再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter.evaluate` | 49 | direct | 右項評価の再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter.evaluate` | 52 | direct | 単項評価の再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter._evaluate_function` | 179 | mutual | `evaluate`との相互再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter._evaluate_function` | 182 | mutual | `evaluate`との相互再帰 |
| `pyprolog/runtime/math_interpreter.py` | `MathInterpreter._evaluate_function` | 186 | mutual | `evaluate`との相互再帰 |
| `pyprolog/runtime/list_builtins.py` | `LengthPredicate._calculate_list_length` | 61 | direct | リスト走査の再帰 |
| `pyprolog/runtime/list_builtins.py` | `LengthPredicate._generate_list` | 72 | direct (tail) | 生成の再帰 |
| `pyprolog/runtime/list_builtins.py` | `SumListPredicate._calculate_sum` | 113 | direct | リスト走査の再帰 |
| `pyprolog/runtime/trace_formatter.py` | `TraceFormatter._render_tree` | 236 | direct | ツリー描画の再帰 |

**Search / Validation / Util**
| ファイル | 関数 | 行 | 再帰パターン | 備考 |
| --- | --- | --- | --- | --- |
| `pyprolog/search/indexer.py` | `SearchIndex._extract_terms_from_body` | 201 | direct | 左側 |
| `pyprolog/search/indexer.py` | `SearchIndex._extract_terms_from_body` | 202 | direct | 右側 |
| `pyprolog/search/indexer.py` | `SearchIndex._extract_terms_from_body` | 205 | direct | 左側 |
| `pyprolog/search/indexer.py` | `SearchIndex._extract_terms_from_body` | 206 | direct | 右側 |
| `pyprolog/search/indexer.py` | `SearchIndex._extract_terms_from_body` | 215 | direct | iterable要素 |
| `pyprolog/search/search_engine.py` | `SearchEngine._extract_terms_from_body` | 187 | direct | 左側 |
| `pyprolog/search/search_engine.py` | `SearchEngine._extract_terms_from_body` | 188 | direct | 右側 |
| `pyprolog/search/search_engine.py` | `SearchEngine._extract_terms_from_body` | 191 | direct | 左側 |
| `pyprolog/search/search_engine.py` | `SearchEngine._extract_terms_from_body` | 192 | direct | 右側 |
| `pyprolog/search/pattern_matcher.py` | `PatternMatcher._count_variables`内`count_vars_recursive` | 231 | direct | 深さ優先 |
| `pyprolog/util/data_exporter.py` | `DataExporter._term_to_string` | 297 | direct | 引数展開 |
| `pyprolog/util/data_exporter.py` | `DataExporter._term_to_json_value` | 355 | direct | 引数展開 |
| `pyprolog/util/data_exporter.py` | `DataExporter._prolog_list_to_json_array` | 391 | mutual | `_term_to_json_value`との相互 |
| `pyprolog/util/formatters.py` | `PrologFormatter._format_term` | 153 | mutual | `_format_compound_term`との相互 |
| `pyprolog/util/formatters.py` | `PrologFormatter._format_compound_term` | 208 | mutual | `_format_term`との相互 |
| `pyprolog/util/formatters.py` | `PrologFormatter._format_list` | 266 | direct | リスト連結の再帰 |
| `pyprolog/validation/dependency_graph.py` | `DependencyGraph.detect_cycles`内`dfs_cycle_detection` | 97 | direct | DFS |
| `pyprolog/validation/dependency_graph.py` | `DependencyGraph.get_strongly_connected_components`内`dfs1` | 154 | direct | DFS |
| `pyprolog/validation/dependency_graph.py` | `DependencyGraph.get_strongly_connected_components`内`dfs2` | 170 | direct | DFS |
| `pyprolog/validation/validator.py` | `Validator._extract_terms_from_body` | 220 | direct | 左側 |
| `pyprolog/validation/validator.py` | `Validator._extract_terms_from_body` | 221 | direct | 右側 |
| `pyprolog/validation/validator.py` | `Validator._extract_terms_from_body` | 224 | direct | 左側 |
| `pyprolog/validation/validator.py` | `Validator._extract_terms_from_body` | 225 | direct | 右側 |
| `pyprolog/validation/validator.py` | `Validator._calculate_rule_complexity`内`count_disjunctions` | 348 | direct | 左側 |
| `pyprolog/validation/validator.py` | `Validator._calculate_rule_complexity`内`count_disjunctions` | 349 | direct | 右側 |

---

**RecursionErrorの原因分析（bench_medium: nrev, primes, recursion_depth）**

**共通のスタック増加点（Python側）**  
`Runtime.execute_iterative`は導入済みですが、ルール本体の実行が`LogicInterpreter._execute_body_direct`と`_execute_conjunction_recursive`により再帰されるため、深いProlog再帰でPythonのスタックが増えます。

**recursion_depth (N=300, bench_light_medium / bench_medium)**
- Prolog定義: `benchmark(N) :- N > 0, N1 is N - 1, benchmark(N1).` (`tests/benchmark/recursion_depth.pl`)
- 呼び出し鎖（概略）  
  `Runtime.execute_iterative` → `GoalFrame.step` → `Runtime._execute_single_goal` → `LogicInterpreter.solve_goal_direct` → `LogicInterpreter._execute_body_direct` → `LogicInterpreter._execute_conjunction_recursive` → `LogicInterpreter._execute_body_direct` → `Runtime._execute_single_goal` → `LogicInterpreter.solve_goal_direct` → …  
- 連言3個+再帰呼び出しが連続するため、N=300でもPython呼び出しが多段化し`RecursionError`に到達。

**nrev (list=150, bench_medium)**
- Prolog定義: `nrev/2`と`append/3`（`tests/benchmark/nrev.pl`）
- 呼び出し鎖（概略）  
  `nrev/2`の再帰 → ルール本体は`_execute_body_direct`/`_execute_conjunction_recursive`経由で深くなる  
  さらに`append/3`は実装側で`AppendPredicate.execute`が自己再帰（`pyprolog/runtime/builtins.py:640`）  
- 2段の再帰（Prolog側+Python側append）でスタックが早く積み上がる。

**primes (limit=1000, bench_medium)**
- Prolog定義: `range/3`, `sieve/2`, `filter/3`（`tests/benchmark/primes.pl`）
- 呼び出し鎖（概略）  
  `range/3`（リスト生成）→ `sieve/2` → `filter/3` → それぞれが`_execute_body_direct`/`_execute_conjunction_recursive`を通じて再帰  
- `range`と`filter`の線形再帰が支配的で、Pythonの再帰限界に近づく。

---

**再帰→反復変換方針（各関数）**

**実行系（RecursionError主因）**
- `LogicInterpreter._execute_body_direct`（1010/1015/1024）: 明示スタック管理。`ExecutionState`/`Frame`に統合し、論理演算子処理をフレーム化。
- `LogicInterpreter._execute_conjunction_recursive`（1104）: 明示スタック。`GoalSeqFrame`の逐次実行に置換。
- `LogicInterpreter.solve_goal`（736/758）: トランポリンまたは`ExecutionState`へ完全統合し、`Runtime.execute`との相互再帰を解消。
- `Runtime._execute_goal_sequence`（257/274）: 既存の反復ロジックを維持しつつ、`execute`呼び出しはフレームを積む方式に変更。
- `Runtime._create_logical_evaluator`（293/301/309）/`_create_control_evaluator`（392/395）: トランポリン化して`execute`の再帰呼び出しを避ける。
- `AppendPredicate.execute`（640）: 明示スタック。`append`の2節をフレーム化し、バックトラックを手動管理。

**データ構造/走査系（深い項での潜在リスク）**
- `LogicInterpreter.deep_dereference_term`（562/574/578）: 明示スタックの深さ優先 or 反復後順。
- `LogicInterpreter.instantiate_term`内`_substitute_vars_in_copy`（1148）: 明示スタック＋`memo`を維持。
- `Runtime._extract_functors_from_term`（117/124）: 明示スタックのDFS/BFS。
- `Runtime._convert_vars_to_japanese`（1242/1264）: 明示スタックのDFS。
- `MathInterpreter.evaluate`（30/48/49/52）: 明示スタックの式評価。もしくはトランポリン。
- `MathInterpreter._evaluate_function`（179/182/186）: `evaluate`の非再帰化に合わせて同様に置換。

**ユーティリティ/表示/検証**
- `PrologFormatter._format_term`/`_format_compound_term`（153/208）: 明示スタックで非再帰の文字列組立に置換。
- `PrologFormatter._format_list`（266）: while＋スタックで線形化。
- `DataExporter._term_to_string`（297）: 明示スタックで引数展開。
- `DataExporter._term_to_json_value`（355）/`_prolog_list_to_json_array`（391）: 単一の反復トラバーサに統合。
- `TraceFormatter._render_tree`（236）: 明示スタックのDFS（前順）。
- `SearchIndex._extract_terms_from_body`（201/202/205/206/215）: 明示スタック。
- `SearchEngine._extract_terms_from_body`（187/188/191/192）: 明示スタック。
- `PatternMatcher._count_variables`内`count_vars_recursive`（231）: 明示スタック。
- `Validator._extract_terms_from_body`（220/221/224/225）: 明示スタック。
- `Validator._calculate_rule_complexity`内`count_disjunctions`（348/349）: 明示スタック。
- `DependencyGraph`内`dfs_cycle_detection`（97）/`dfs1`（154）/`dfs2`（170）: 明示スタックDFS。
- `BindingEnvironment.get_value`（59）: whileで親チェーンを走査。
- `BindingEnvironment.merge_with`（111）: 親チェーンをループでマージ。
- `BindingEnvironment.to_dict`（129）: 親チェーンをループで合成。
- `ListTerm.to_internal_list_term`（109）: tailを辿るwhile＋反転構築。

**パーサ**
- `Parser._parse_expression_with_precedence`（257/294）/`_parse_primary`（340）/`_parse_list`（399/412）: 反復型のprecedence climbing（またはshunting-yard）に置換。実装コストは高いが技術的には可能。

---

**段階的実装計画**

**Phase 1（Critical: bench_medium RecursionErrorを止める）**
1. `LogicInterpreter._execute_body_direct`と`_execute_conjunction_recursive`をExecutionFrame/ExecutionStateに統合。  
2. `LogicInterpreter.solve_goal_direct`を“フレーム生成”方式に変更し、`Runtime._execute_single_goal`との相互再帰を断つ。  
3. `AppendPredicate.execute`を明示スタック化。  
4. 回帰確認: `tests/benchmark/test_benchmarks.py`の`nrev`/`primes`/`recursion_depth`（light-medium/medium）と`tests/runtime/test_iterative_execution.py`。

**Phase 2（Secondary: 深い項・大きな出力）**
1. `deep_dereference_term`、`_substitute_vars_in_copy`、`_convert_vars_to_japanese`、`_extract_functors_from_term`を反復化。  
2. `MathInterpreter.evaluate`を反復評価に変更。  
3. 回帰確認: `tests/runtime/test_recursive_rules.py`、`tests/runtime/test_list_operations.py`、`tests/core/test_types.py`。

**Phase 3（Full iterative conversion）**
1. パーサの反復化（precedence climbingのスタック化）。  
2. `formatter`/`data_exporter`/`trace_formatter`/`search`/`validator`/`dependency_graph`の再帰をすべて反復に置換。  
3. 回帰確認: `tests/tools/test_explain_tool.py`、`tests/tools/test_search_tool.py`、`tests/tools/test_validate_tool.py`、`tests/integration/*`。

---

**リスク評価（何が壊れうるか / 影響テスト）**
- **バックトラック順序の変化**: 明示スタック化で解の列挙順が変わる可能性。  
  影響: `tests/runtime/test_recursive_rules.py`, `tests/runtime/test_iterative_execution.py`.
- **cut/negationの意味論**: `\+`や`!`のスコープがズレると大きな不具合。  
  影響: `tests/runtime/test_iterative_execution.py`, `tests/runtime/test_recursive_rules.py`.
- **append/3のロジック変数挙動**: `append/3`の多方向性・不完全リストでの挙動が変わる可能性。  
  影響: `tests/runtime/test_list_operations.py`, `tests/integration/test_end_to_end.py`.
- **トレース出力の順序/整形**: `_render_tree`や実行順序変更で表示が変化。  
  影響: `tests/tools/test_explain_tool.py`.
- **検索/検証結果の順序**: DFS→BFS変換で出力順が変化。  
  影響: `tests/tools/test_search_tool.py`, `tests/tools/test_validate_tool.py`.
- **パーサ互換性**: 優先順位・結合性の挙動に差が出る可能性。  
  影響: `tests/parser/test_parser.py`, `tests/core/test_new_operators.py`.

---

必要なら、Phase 1の具体的なフレーム設計（`ExecutionState`に「ルール本体フレーム」「ユーザ定義述語フレーム」を追加する案）を次に詳細化できます。  
次の一手として、どのフェーズから実装に着手するか選んでもらえれば、変更案を具体的に作ります。

**提案する次のステップ**
1. Phase 1の詳細設計（新しいフレーム構造と遷移図）  
2. `AppendPredicate.execute`の明示スタック案を先に確定  
3. `_execute_body_direct`の反復化を先行プロトタイプ化
