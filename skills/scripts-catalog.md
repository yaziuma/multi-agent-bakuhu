# scripts/ カタログ

> **⚠️ 重要**: 専用スクリプトがあるならそれを使え。
> 手動で `tmux send-keys` やinboxファイルの直接操作をするな。
> このカタログを参照し、目的に合ったスクリプトを呼び出せ。

---

## 1. エージェント操作系

### check_context.sh
```bash
bash scripts/check_context.sh <agent_id>
# 例
bash scripts/check_context.sh karo
bash scripts/check_context.sh ashigaru1
```

**引数**: `agent_id` — 対象エージェントのID（karo, ashigaru1, 等）

**用途**: 対象エージェントのコンテキスト使用率（%）を取得。`/context` コマンドをエージェントのpaneに送信し、出力から割合を抽出して stdout に出力する。

**注意点**:
- エージェントのpaneが存在しないとエラー（exit 1）
- コンテキスト取得に3秒かかる（/context の出力待機）
- 将軍がこのスクリプトで家老の使用率を測定するのが標準運用
- 自己測定は禁止（自分のコンテキストを消費するため不正確）

---

### run_compact.sh
```bash
bash scripts/run_compact.sh <agent_id>
# 例
bash scripts/run_compact.sh karo
bash scripts/run_compact.sh ashigaru1
```

**引数**: `agent_id` — /compact を実行させるエージェントのID

**用途**: 対象エージェントに `/compact` コマンドを送信し、完了まで待機。完了後に `check_context.sh` でコンテキスト使用率を確認して出力する。

**注意点**:
- タイムアウト60秒（compactは時間がかかる）
- 完了確認は "Compacted" 文字列の出現を監視（case-insensitive grep、大文字小文字を区別しない）
- 完了後さらに10秒待機してからコンテキスト確認
- compact後のコンテキスト%をstdoutに出力

---

### run_clear.sh
```bash
bash scripts/run_clear.sh <agent_id>
# 例
bash scripts/run_clear.sh ashigaru1
bash scripts/run_clear.sh denrei1
```

**引数**: `agent_id` — /clear を実行させるエージェントのID

**用途**: 対象エージェントに `/clear` コマンドを送信してセッションをリセット。完了確認は `❯` プロンプトの出現を監視する。

**注意点**:
- タイムアウト10秒
- /clear 後はエージェントのコンテキストが消える（CLAUDE.md再読から始まる）
- 足軽の `redo` や緊急リセット時に使用
- 通常は inbox_watcher のエスカレーション機能経由で自動実行される

---

### shogun_karo_status.sh
```bash
bash scripts/shogun_karo_status.sh
```

**引数**: なし

**用途**: 家老pane（multiagent:0.0）の最新20行を表示。コマンド送信前に家老が作業中かどうかを目視確認するために使用。

**注意点**:
- pane番号ハードコード（multiagent:0.0 = karo固定）
- あくまで目視確認用。状態判定の自動化には使わない

---

### shogun_whoami.sh
```bash
bash scripts/shogun_whoami.sh
```

**引数**: なし

**用途**: 現在のtmux paneの `@agent_id` を表示。将軍がセッション開始時に自分のidentityを確認するために使用。

**注意点**:
- tmux外では空文字になる
- `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` と等価

---

## 2. 通信系

### inbox_write.sh
```bash
bash scripts/inbox_write.sh <target_agent> "<content>" [type] [from]
# 例
bash scripts/inbox_write.sh karo "cmd_048を実行せよ。" cmd_new shogun
bash scripts/inbox_write.sh ashigaru1 "タスクYAML読んで作業開始せよ。" task_assigned karo
bash scripts/inbox_write.sh karo "足軽1号、任務完了。" report_done ashigaru1
```

**引数**:
- `target_agent`: 送信先エージェントID
- `content`: メッセージ本文（クォートで囲む）
- `type`: メッセージタイプ（省略時: wake_up）。代表値: `cmd_new`, `task_assigned`, `report_done`, `report_received`
- `from`: 送信元エージェントID（省略時: unknown）

**用途**: エージェント間の通信メッセージを相手の inbox YAML に書き込む。排他ロック（flock）付きアトミック書き込みで確実に届く。最大50件でオーバーフロー保護あり。

**注意点**:
- tmux send-keys で直接メッセージを送るな。必ずこのスクリプトを使え
- `clear_command` / `model_switch` タイプは inbox_watcher が特別処理する
- 送信後、inbox_watcher がエージェントをウェイクアップする

---

### inbox_watcher.sh
```bash
bash scripts/inbox_watcher.sh <agent_id> [pane_target] [cli_type]
# 例
bash scripts/inbox_watcher.sh karo          # 動的pane解決（推奨）
bash scripts/inbox_watcher.sh ashigaru1
bash scripts/inbox_watcher.sh ashigaru1 "" codex  # CLI種別指定
```

**引数**:
- `agent_id`: 監視対象エージェントID
- `pane_target`: pane ID（省略時または `""`: @agent_idから動的解決）
- `cli_type`: CLIの種別（claude/codex/copilot/kimi、省略時: claude）

**用途**: エージェントの inbox YAML を `inotifywait` で監視し、未読メッセージがあればtmux send-keysでウェイクアップ通知を送る常駐デーモン。エスカレーション機能あり（0-2分: 通常nudge、2-4分: Escape+nudge、4分以上: /clear送信）。

**注意点**:
- 通常 `watcher_supervisor.sh` が自動起動するため直接呼ぶことは稀
- `inotify-tools` が必要（`sudo apt install inotify-tools`）
- `clear_command`/`model_switch` タイプのメッセージを受信すると `/clear` や `/model` を代理送信する

---

### ntfy.sh
```bash
bash scripts/ntfy.sh "<メッセージ>"
# 例
bash scripts/ntfy.sh "cmd_XXX完了。将軍確認求む。"
```

**引数**: `message` — 通知メッセージ文字列

**用途**: ntfy.sh サービス経由でスマートフォンにプッシュ通知を送信する。`config/settings.yaml` の `ntfy_topic` 設定を使用。認証あり（Bearer token / Basic auth）。

**注意点**:
- `config/settings.yaml` に `ntfy_topic` が設定されている必要がある
- 認証処理は `lib/ntfy_auth.sh` 経由（Bearer token / Basic auth / 認証なし）。設定ファイル: `config/ntfy_auth.env`（git非追跡）
- 自分が送ったメッセージは `outbound` タグでフィルタされ、ntfy_listener が再受信しない

---

### ntfy_listener.sh
```bash
bash scripts/ntfy_listener.sh
```

**引数**: なし

**用途**: ntfyトピックのストリーミングエンドポイントに接続し、受信メッセージを `queue/ntfy_inbox.yaml` に書き込み、shogun の inbox に転送する常駐デーモン。ポーリングではなく長期接続ストリーミング。

**注意点**:
- 接続切断時は5秒後に自動再接続
- `outbound` タグのメッセージ（自分が送ったもの）はスキップ
- shogun の inbox_watcher が shogun をウェイクアップする

---

## 3. インフラ系

### watcher_supervisor.sh
```bash
bash scripts/watcher_supervisor.sh
```

**引数**: なし

**用途**: 全エージェントの inbox_watcher を5秒ごとに生存確認し、停止していれば再起動する永続監視デーモン。`config/settings.yaml` から `ashigaru_count` と `max_count`（denrei数）を**起動時に一度だけ読み取る**（ホットリロードなし。設定変更後は watcher_supervisor.sh の再起動が必要）。

**注意点**:
- shutsujin_departure.sh が起動時に自動開始する
- エージェントのpaneが存在しない場合はwatcher起動しない（正常動作）
- 設定ファイル不読み込みの場合は ashigaru=2, denrei=1 にフォールバック

---

### restart_all_watchers.sh
```bash
bash scripts/restart_all_watchers.sh
```

**引数**: なし

**用途**: 実行中の全 inbox_watcher を停止し、全エージェント分を再起動する。watcher設定変更後や異常検知時に使用。

**注意点**:
- 既存watcherをpkillで全停止後に再起動（2秒待機）
- **ハードコード**: shogun, karo, ashigaru1-3, denrei1-2 固定（`watcher_supervisor.sh` は settings.yaml を起動時に一括読取するため、`ashigaru_count` 変更時はこのスクリプトのハードコード部分も手動修正が必要）
- 通常は `watcher_supervisor.sh` に任せ、このスクリプトは緊急時のみ使用

---

### yaml_archive_done.sh
```bash
bash scripts/yaml_archive_done.sh
```

**引数**: なし

**用途**: `queue/shogun_to_karo.yaml` の `status: done/completed` なコマンドを `logs/archive/YYYY-MM-DD/` に退避し、元ファイルからアクティブコマンドのみを残す。

**注意点**:
- 内部で `yaml_archive_done.py` を呼ぶラッパー
- `yaml_archive_watcher.sh` が自動実行するため、手動実行は整理したい時のみ

---

### yaml_archive_done.py
```bash
python3 scripts/yaml_archive_done.py
# 通常は yaml_archive_done.sh 経由で呼ぶ
```

**引数**: なし

**用途**: `yaml_archive_done.sh` の実装本体。YAML読み書き・アーカイブファイル作成を行う。

**注意点**:
- **カレントディレクトリ依存**: プロジェクトルートから実行する必要がある（`queue/shogun_to_karo.yaml` をcwdからの相対パスで解決するため）
- `PyYAML` が必要
- `queue/shogun_to_karo.yaml` が存在しない場合はエラー終了

---

### yaml_archive_watcher.sh
```bash
bash scripts/yaml_archive_watcher.sh
```

**引数**: なし

**用途**: `queue/shogun_to_karo.yaml` の変更を `inotifywait` で監視し、変更があれば自動的に `yaml_archive_done.sh` を実行する常駐デーモン。PIDファイルで多重起動防止。

**注意点**:
- 1秒のdebounce（連続変更をまとめる）
- `done: 0` の場合はログスキップ（ノイズ削減）
- PIDファイル: `logs/yaml_archive_watcher.pid`

---

## 4. ビルド・セットアップ系

### build_instructions.sh
```bash
bash scripts/build_instructions.sh
```

**引数**: なし

**用途**: 各ロール（shogun/karo/ashigaru）× CLI種別（claude/codex/copilot/kimi）の instruction ファイルを `instructions/generated/` に生成する。またCLI固有の自動読込ファイル（AGENTS.md、copilot-instructions.md、agents/default/system.md）も生成する。

**注意点**:
- `instructions/roles/` と `instructions/common/` のパーツファイルを組み合わせる
- 生成物は `instructions/generated/` に出力（gitignore対象の可能性あり）
- CLAUDE.md が正本。各CLI用は CLAUDE.md を sed 変換して生成

---

### setup-branch-protection.sh
```bash
bash scripts/setup-branch-protection.sh [REPO]
# 例
bash scripts/setup-branch-protection.sh yaziuma/multi-agent-bakuhu
```

**引数**: `REPO` — `owner/repo` 形式（省略時: `yaziuma/multi-agent-bakuhu`）

**用途**: GitHub API 経由で main ブランチの保護設定を行う（PR必須・1承認・CODEOWNERS承認・force push禁止等）。

**注意点**:
- `gh` CLI コマンドが必要（GitHub CLI）
- GitHub 認証が完了している必要がある
- 一度だけ実行すればよい（リポジトリ初期設定用）

---

## 5. ユーティリティ系

### extract-section.sh
```bash
bash scripts/extract-section.sh <markdown-file> "<heading-text>"
# 例
bash scripts/extract-section.sh dashboard.md "## 🚨要対応"
bash scripts/extract-section.sh dashboard.md "## 現在のタスク状況"
```

**引数**:
- `markdown-file`: 対象Markdownファイルのパス
- `heading-text`: 抽出するセクションの見出し（`#` と半角スペースを含む完全一致）

**用途**: Markdownファイルから指定した見出しのセクション内容を抽出して stdout に出力する。同レベル以上の次の見出しで自動停止。

**注意点**:
- 見出しテキストは `## Section` のように `#` と半角スペースを含む形式で指定
- 見つからない場合は exit 1
- awk 実装のため yq/jq 等の外部ツール不要

---

### gemini_cached.sh
```bash
bash scripts/gemini_cached.sh "<クエリ>" [出力ファイル]
# 例
bash scripts/gemini_cached.sh "Pythonのasyncioについて説明せよ"
bash scripts/gemini_cached.sh "調査内容" output.md
```

**引数**:
- `query`: Gemini に送るクエリ文字列
- `output_file`: 出力先ファイルパス（省略時: stdout）

**用途**: Gemini CLI（`gemini` コマンド）のキャッシュ付きラッパー。同一クエリは24時間キャッシュされ、再実行時はAPIコールを省略する。リトライ機能（最大3回）と出力検証あり。

**注意点**:
- `gemini` CLI が必要
- キャッシュ保存先: `~/.cache/gemini_cache/`
- キャッシュキーはクエリの sha256 ハッシュ
- 切り詰めパターン検出は警告のみ（エラーにはしない）

---

### auto_approve.exp
```bash
expect scripts/auto_approve.exp "<claude コマンド引数>"
# 例
expect scripts/auto_approve.exp "claude -p 'タスクを実行せよ'"
```

**引数**: `command` — 実行する claude コマンド全体（文字列）

**用途**: Claude Code の許可プロンプト（[y/N]、Allow?、Proceed? 等）を自動的に "y" または Enter で応答するラッパー。非対話的な自動化スクリプトから Claude Code を呼び出す際に使用。

**注意点**:
- `expect` が必要（`sudo apt install expect`）
- タイムアウト300秒
- セキュリティ上の注意: 実行するコマンドを必ず確認すること

---

### karo_reporter.sh
```bash
bash scripts/karo_reporter.sh
```

**引数**: なし

**用途**: `queue/reports/urgent/` と `queue/reports/normal/` を監視し、報告YAMLを処理して `dashboard.md` を更新する常駐デーモン。緊急報告は即時処理、通常報告はバックグラウンド処理。

**注意点**:
- `inotify-tools` が必要
- `requires_human: true` の緊急報告は `queue/EMERGENCY.flag` を立てる
- 現状は実験的機能（通常の報告フローは inbox_write + YAML報告が主体）

---

## 6. Identity系

### get_pane_id.sh
```bash
bash scripts/get_pane_id.sh
```

**引数**: なし（環境変数 `$TMUX_PANE` を使用）

**用途**: 現在のtmux pane ID（`%N` 形式）を stdout に出力する。Identity分離設計書v3 セクション1 準拠。

**注意点**:
- tmux外で実行すると exit 1（通常コンテキスト）または exit 2（hookコンテキスト）
- hookコンテキスト（`HOOK_CONTEXT=true`）では fail-closed（exit 2）
- `get_agent_role.sh` の内部から自動呼び出しされる

---

### get_agent_role.sh
```bash
bash scripts/get_agent_role.sh [pane_id]
# 例
bash scripts/get_agent_role.sh        # 現在のpaneのroleを取得
bash scripts/get_agent_role.sh %3     # 指定paneのroleを取得
```

**引数**: `pane_id` — 省略時は `get_pane_id.sh` で自動取得

**用途**: pane IDから `config/pane_role_map.yaml` を参照してロール名（shogun/karo/ashigaru/denrei）を取得。sha256整合性チェックと `@agent_id` とのクロスチェックを行う。

**注意点**:
- `config/pane_role_map.yaml` が存在しないと exit 2（fail-closed）
- sha256不一致の場合も exit 2
- pane IDがマップに存在しない場合も exit 2
- hookスクリプトが role 判定に使用する正式手段

---

### selftest_hooks.sh
```bash
bash scripts/selftest_hooks.sh
```

**引数**: なし

**用途**: Identity分離基盤の整合性を総合チェックするセルフテスト。ポリシーファイル・hookスクリプト・hook_common.sh・コアスクリプト・pane_role_map.yaml の存在、実行権限、sha256整合性、epochの一致を検証する。

**戻り値**:
- `exit 0`: 全テストパス（またはWARNINGのみ）
- `exit 2`: 致命的エラーあり

**注意点**:
- エラー時は安定版ポリシーへのロールバック手順を表示
- 自動ロールバックは無効（安全のため手動実行が必要）
- セッション起動前の確認に使用

---

## 7. ライブラリ

### scripts/lib/resolve_pane.sh
```bash
source scripts/lib/resolve_pane.sh
PANE_ID=$(resolve_pane "karo")
PANE_ID=$(resolve_pane "ashigaru1")
```

**提供関数**: `resolve_pane <agent_id>` — pane_id を stdout に出力、見つからなければ exit 1

**用途**: agent_id（文字列）から tmux pane ID（`%N`）を動的に解決する共有ライブラリ。`multiagent` セッション → `shogun` セッションの順で全paneを探索し、`@agent_id` カスタム変数と照合する。

**注意点**:
- `check_context.sh`、`run_compact.sh`、`run_clear.sh` が内部で使用
- pane番号のハードコードを排除するための仕組み（pane再配置に強い）

---

### scripts/lib/hook_common.sh
```bash
source scripts/lib/hook_common.sh
# 主要関数:
get_role             # pane_role_map.yamlからロール解決
check_role_match "karo"  # 非担当ロールはexit 0で即終了
hook_log "hook名" "rule" "詳細" "decision"  # 構造化ログ
read_command_from_stdin   # stdin JSONからコマンド取得
read_filepath_from_stdin  # stdin JSONからファイルパス取得
normalize_path "<path>"   # realpathでパス正規化
```

**用途**: 全hookスクリプト共有のライブラリ。ロール解決・チェック・ログ出力・入力パース等の共通機能を提供。source時に自動的に `verify_hook_common_integrity()` + `verify_epoch()` を実行してセキュリティを担保する。

**注意点**:
- hookスクリプトからのみ source する（エージェント本体から直接呼ぶな）
- パーミッション 444（read-only）が期待値
- sha256 整合性チェックで改ざん検出時は exit 2（fail-closed）
- tmux外/HOOK_CONTEXT未設定の場合は exit 0 でスルー（Task tool等への影響を排除）

---

## 8. プロジェクトルートライブラリ（lib/）

### lib/ntfy_auth.sh
```bash
source lib/ntfy_auth.sh
AUTH_ARGS=$(ntfy_get_auth_args)
ntfy_validate_topic "$NTFY_TOPIC"
```

**提供関数**:
- `ntfy_get_auth_args [auth_env_file]` — curl認証フラグを stdout に返す（Bearer token / Basic auth / 認証なし）
- `ntfy_validate_topic <topic>` — トピック名の強度検証（0=OK, 1=弱い）

**用途**: `ntfy.sh` が内部で source する認証ヘルパーライブラリ。`config/ntfy_auth.env` から認証情報（`NTFY_TOKEN` / `NTFY_USER`+`NTFY_PASS`）を読み込み、curl に渡すフラグを返す。

**注意点**:
- `ntfy.sh` の内部から自動 source されるため、直接呼ぶことは稀
- 認証設定ファイル: `config/ntfy_auth.env`（git非追跡。手動作成）
- 認証方式の優先順位: Bearer token → Basic auth → 認証なし（後方互換）

---

### lib/cli_adapter.sh
```bash
source lib/cli_adapter.sh
CLI_TYPE=$(get_cli_type "ashigaru1")    # → "claude" | "codex" | "copilot" | "kimi"
CMD=$(build_cli_command "karo")         # → "claude --model opus --dangerously-skip-permissions"
MODEL=$(get_agent_model "ashigaru1")    # → "sonnet"
```

**提供関数**:
- `get_cli_type <agent_id>` — CLI種別を返す（"claude" / "codex" / "copilot" / "kimi"）
- `build_cli_command <agent_id>` — エージェント起動コマンド文字列を返す
- `get_instruction_file <agent_id [,cli_type]>` — CLI別の指示書ファイルパスを返す
- `validate_cli_availability <cli_type>` — 0=利用可能, 1=利用不可
- `get_agent_model <agent_id>` — モデル名を返す（opus/sonnet/haiku/k2.5）

**用途**: Multi-CLI統合設計書 §2.2 準拠のCLI抽象化レイヤー。`config/settings.yaml` の `cli.agents.{id}` セクションを読み取り、エージェントごとのCLI種別・モデルを動的解決する。`shutsujin_departure.sh` が source して使用。

**注意点**:
- `python3` と `PyYAML` が必要（YAML読み取りに使用）
- `config/settings.yaml` の `cli.agents` セクションが未設定の場合は `claude` にフォールバック
- 新CLIを追加する際は `build_cli_command` 関数のcase文を修正する

---

## 将軍の行動早見表

| やりたいこと | 使うスクリプト |
|-------------|---------------|
| 家老コンテキスト確認 | `bash scripts/check_context.sh karo` |
| 家老に/compact実行 | `bash scripts/run_compact.sh karo` |
| 足軽に/clear実行 | `bash scripts/run_clear.sh ashigaru1` |
| 家老にcmd伝達 | `bash scripts/inbox_write.sh karo "msg" cmd_new shogun` |
| 家老pane目視確認 | `bash scripts/shogun_karo_status.sh` |
| ダッシュボード抽出 | `bash scripts/extract-section.sh dashboard.md "## 見出し"` |
| スマホ通知 | `bash scripts/ntfy.sh "メッセージ"` |
| 全watcher再起動 | `bash scripts/restart_all_watchers.sh` |
| done済みcmd退避 | `bash scripts/yaml_archive_done.sh` |
| Hook整合性テスト | `bash scripts/selftest_hooks.sh` |
| 自分のidentity確認 | `bash scripts/shogun_whoami.sh` |
