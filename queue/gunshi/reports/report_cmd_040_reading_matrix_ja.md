# 既存運用調査: 各段階で誰がどのファイルをどこまで読むか

## 調査対象
- instructions/*.md
- CLAUDE.md

## 段階1: セッション開始（初回起動）

### 将軍（Shogun）
- 必須:
  - CLAUDE.md
  - instructions/shogun.md
  - Memory MCP (mcp__memory__read_graph)
- 指示書の「コンテキスト読み込み手順」により追加:
  - config/projects.yaml
  - 対象プロジェクトの README.md / CLAUDE.md
  - dashboard.md（参考情報）

### 家老（Karo）
- 必須:
  - CLAUDE.md
  - instructions/karo.md
  - Memory MCP (mcp__memory__read_graph)
- 指示書の「コンテキスト読み込み手順」により追加:
  - config/projects.yaml
  - queue/shogun_to_karo.yaml
  - context/{project}.md（存在すれば）

### 足軽（Ashigaru）
- 必須:
  - CLAUDE.md
  - instructions/ashigaru.md
  - Memory MCP (mcp__memory__read_graph)
- 追加:
  - 自分専用の queue/tasks/ashigaru{N}.yaml のみ
  - task に project があれば context/{project}.md
  - target_path と関連ファイル

### 伝令（Denrei）
- 必須:
  - CLAUDE.md
  - instructions/denrei.md
  - Memory MCP (mcp__memory__read_graph)
- 追加:
  - 自分専用の queue/denrei/tasks/denrei{N}.yaml のみ

### 忍び / 軍師（外部）
- 常駐しないため「呼び出し時に依頼YAMLと必要ファイルのみ読む」方針

---

## 段階2: 通常ワークフロー（指示受領〜報告）

### 将軍
- 読む:
  - queue/shogun_to_karo.yaml（指示状況）
  - dashboard.md（家老の報告のみ）

### 家老
- 読む:
  - queue/shogun_to_karo.yaml（指示受領）
  - queue/tasks/ashigaru{N}.yaml（割当状況）
  - queue/reports/ashigaru*_report.yaml（**全件スキャン**と明記）
- 更新:
  - dashboard.md（進行中・戦果）

### 足軽
- 読む:
  - 自分専用の queue/tasks/ashigaru{N}.yaml のみ
- 書く:
  - queue/reports/ashigaru{N}_report.yaml
- 他足軽ファイルは読むな（明示）

### 伝令
- 読む:
  - 自分専用の queue/denrei/tasks/denrei{N}.yaml のみ
- 書く:
  - queue/denrei/reports/denrei{N}_report.yaml

### 忍び（Shinobi）
- 伝令経由で召喚。
- 成果物は queue/shinobi/reports/ に保存。
- 伝令は全文読まず head で要約取得運用が明示。

### 軍師（Gunshi）
- 伝令経由で召喚。
- 成果物は queue/gunshi/reports/ に保存。
- 軍師は read-only。

---

## 段階3: コンパクション復帰

### 将軍
- 一次情報:
  - queue/shogun_to_karo.yaml
  - config/projects.yaml
  - Memory MCP
  - context/{project}.md（存在すれば）
- 二次情報:
  - dashboard.md（参考のみ）

### 家老
- 一次情報:
  - queue/shogun_to_karo.yaml
  - queue/tasks/ashigaru{N}.yaml
  - queue/reports/ashigaru{N}_report.yaml（全件）
  - Memory MCP
  - context/{project}.md（存在すれば）
- 二次情報:
  - dashboard.md（参考のみ）

### 足軽
- 一次情報:
  - queue/tasks/ashigaru{N}.yaml（自分専用のみ）
  - Memory MCP
  - context/{project}.md（必要時のみ）

### 伝令
- 一次情報:
  - queue/denrei/tasks/denrei{N}.yaml（自分専用のみ）
  - Memory MCP

---

## 段階4: /clear 後の復帰

### 足軽（明示的に instructions 再読不要）
- 読む:
  - CLAUDE.md（自動読み込み）
  - Memory MCP
  - queue/tasks/ashigaru{N}.yaml
  - context/{project}.md（必要時のみ）
- instructions/ashigaru.md は読まない（コスト節約の明示）

### 伝令（明示的に instructions 再読不要）
- 読む:
  - CLAUDE.md（自動読み込み）
  - Memory MCP
  - queue/denrei/tasks/denrei{N}.yaml
- instructions/denrei.md は読まない（コスト節約の明示）

### 将軍/家老
- /clear 専用の軽量化指示は明記されていないため、通常の復帰手順に従う運用

---

## 重要な「読む範囲」ルール（既存明文化）

- 足軽/伝令は **自分専用ファイルのみ**読む。
- 家老は **全報告ファイルを毎回スキャン**する（通信ロスト対策）。
- /clear 後は足軽・伝令は instructions を再読しない。
- 忍びは全文ではなく要約取得（head）を推奨。


---

## 追記: 古い物・終了タスク・履歴の扱い（読み取り期間/削除）

### 1) 既存ルールで「いつまで読むか」
- **家老**: 報告受信時に `queue/reports/ashigaru*_report.yaml` を**毎回全件スキャン**する、と明記されている。= **古い報告も対象になりうる**（明確な打ち切り条件は未定義）。
- **将軍**: `dashboard.md` を読むが、これは家老がまとめた二次情報。古い履歴の範囲は明記なし。
- **足軽/伝令**: 自分専用ファイルのみ読む。過去分を読むルールはなく、**最新状態のみ**運用。
- **忍び/軍師報告**: 既存報告の再利用が推奨されており、**過去の報告を参照する前提**（削除前提ではない）。

### 2) 既存ルールで「削除されるか」
- **/clear**: 会話コンテキストのみリセット。ファイルは残る（CLAUDE.md/README_ja.md の説明）。
- **shutsujin_departure.sh -c/--clean**:
  - **実行時のみ**キューとダッシュボードをリセット。
  - その際、`dashboard.md` と `queue/reports`, `queue/tasks`, `queue/shogun_to_karo.yaml` を **`logs/backup_YYYYmmdd_HHMMSS/` にバックアップ** してから初期化する。
  - **通常起動（--clean なし）では削除されない**。
- **常時の自動削除/保持期間（TTL）**: 既存ドキュメント・設定・スクリプトに明確な記述は見当たらない。

### 3) 実態としての「履歴の蓄積」
- `dashboard.md` は履歴セクションを持ち、過去の完了タスクが残る運用。
- `queue/*/reports/` は明示的に削除しない限り残る運用。
- `queue/*/tasks/` は各タスクごとに上書きされるため、過去履歴は原則残らない（**最新状態のみ**）。

### 4) 結論（現行の仕様）
- **明確な「いつまで読むか」「いつ削除するか」の保持ポリシーは未定義。**
- 実質は以下の二系統：
  - **履歴を残す系**: `dashboard.md`, `queue/*/reports/`, `queue/gunshi/reports/`, `queue/shinobi/reports/`
  - **最新状態のみ系**: `queue/*/tasks/`, `queue/shogun_to_karo.yaml`
- 明示的な削除は **`shutsujin_departure.sh --clean` 実行時のみ**（バックアップ後に初期化）。


---

## 追記: 退避ポリシー案（不要検知 → 退避）

### A. 不要判定の基本方針（候補）
- **task YAML（queue/tasks/ashigaru{N}.yaml）**
  - `status: done` かつ **対応する report が家老に反映済み**（dashboard.md の戦果に反映）なら「不要」と判断
- **report YAML（queue/reports/ashigaru*_report.yaml）**
  - `dashboard.md` に反映済み かつ **一定期間経過**（例: 7日）で退避対象
- **dashboard.md 履歴**
  - 完了から一定期間（例: 30日）経過した行は「履歴アーカイブ」に移す
- **shogun_to_karo.yaml**
  - `status: done` かつ一定期間経過で退避対象（ただし履歴画面で必要なら保持）

※ 退避は削除ではなく**アーカイブ移動**（復元可能）を前提とする。

---

## 退避の実装案（Linux/Python/一時エージェント）

### 1) Linux標準ツールによる退避（cron + find + tar）
- 例: 完了から7日経過した report を `logs/archive/` に移動
- 長所: 依存追加なし、軽量
- 短所: 判定ロジックが単純（YAMLの状態依存が難しい）

### 2) Python による退避（YAML判定ベース）
- report の `task_id` と `dashboard.md` を突合
- `status: done` かつ dashboard 反映済みなら退避
- 退避先に日付サブディレクトリを作成
- 長所: ルールを柔軟にできる
- 短所: 実装・運用コストがやや増える

### 3) 一時エージェントによる退避（非常駐・低コスト）
- **想定**: 整理専用の一時エージェント（呼ばれた時だけ動作）
- **モデル**: Haiku 等の低コストモデルを推奨
- **役割**: 退避対象の抽出・整理計画の作成・必要ファイルの移動手順提案
- **長所**: 人手コスト削減、必要時のみ起動で常駐コストなし
- **短所**: 実装ロジックの自動化は限定的（最終実行はスクリプト or 家老判断）

---

## 構想: 「不要判定ルール + 一時エージェント」の組み合わせ運用

### 目的
- 不要な履歴・報告を **安全に退避** し、読み込みコストと探索コストを下げる
- 常駐の負荷を増やさず、必要時だけ **低コストで整理** する

### 運用イメージ（定期 or 手動トリガー）
1. **家老がトリガー**: 「整理フェーズ」に入ったら一時エージェントを呼ぶ  
2. **一時エージェント（Haiku等）が実施**:  
   - 退避候補リストを作成（YAML/ダッシュボード照合）  
   - 退避計画（移動対象/保存先/実行手順）を出力  
3. **家老が最終確認**: 退避計画を承認  
4. **退避実行**: 家老がスクリプトで移動（削除はしない）  

### 判定ルール（提案・再掲）
- **task YAML**: `status: done` かつ dashboard に反映済み → 退避候補  
- **report YAML**: dashboard 反映済み + 経過日数（例: 7日） → 退避候補  
- **dashboard.md 履歴**: 完了から一定期間（例: 30日） → 履歴アーカイブ候補  
- **shogun_to_karo.yaml**: `status: done` + 経過日数 → 退避候補  

### 出力フォーマット（例）
```
## Archive Candidates
- queue/reports/ashigaru1_report.yaml  (done, dashboard反映済, 7日経過)
- queue/reports/ashigaru2_report.yaml  (done, dashboard反映済, 12日経過)

## Proposed Moves
- queue/reports/*  -> logs/archive/2026-02-06/reports/
- dashboard.md 履歴部 -> logs/archive/2026-02-06/dashboard_history.md
```

### 退避先（例）
- `logs/archive/YYYY-MM-DD/`  
  - `reports/`  
  - `tasks/`  
  - `dashboard_history.md`  
  - `shogun_to_karo.yaml`（doneのみ）

### 長所
- 低コスト（必要時のみ起動）  
- ルールは明文化され、判断の属人化を回避  
- 削除ではなく退避のため安全

### 留意点
- **削除はしない**（復元前提）  
- 退避後は「参照が必要な人」のために index ファイルを残す  

---

## shutsujin_departure.sh --clean の実動作（バックアップ＋初期化）

### 1) バックアップ作成（--clean時のみ）
- バックアップ先: `./logs/backup_YYYYmmdd_HHMMSS/`
- **dashboard.md が存在し、かつ "cmd_" が含まれている場合のみ**バックアップ作成
- 保存対象:
  - `dashboard.md`
  - `queue/reports/`
  - `queue/tasks/`
  - `queue/shogun_to_karo.yaml`

### 2) 初期化（--clean時のみ）
- `queue/tasks/ashigaru{N}.yaml` を初期状態に上書き
- `queue/reports/ashigaru{N}_report.yaml` を初期状態に上書き
- 伝令/忍び/軍師関連のキューも初期化対象
- `dashboard.md` もクリーン状態にリセット

### 3) 非clean時
- `--clean` 指定がない通常起動では**削除もリセットも行わない**
