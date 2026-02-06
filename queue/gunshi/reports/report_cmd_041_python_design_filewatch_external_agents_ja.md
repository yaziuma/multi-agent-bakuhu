# 設計書: Python導入（B. ファイル監視 / E. 外部エージェント召喚）

## 前提
- 既存の **YAML + tmux send-keys** を正データ・イベント駆動の根幹として維持
- **ポーリング禁止（F004）**を遵守
- 変更は「補助ツール」として追加し、現行運用を壊さない

---

# B. ファイル監視（watchdog）設計

## 目的
- inotifywait依存の脆弱性を解消し、**堅牢なイベント駆動**に置き換える
- 既存の「報告が届いたら家老を起こす」フローを維持

## 対象ディレクトリ
- `queue/reports/`
- `queue/denrei/reports/`
- （必要に応じて）`queue/shinobi/reports/` `queue/gunshi/reports/`

## 監視対象イベント
- `created` / `moved_to`（新規作成・置換）
- `modified` は**基本無視**（部分書き込みの誤検知を避ける）

## 動作フロー
1. watchdogが対象ディレクトリを監視
2. **YAMLファイル作成/移動を検知**
3. ルール判定:
   - 通常報告 → 家老を起こす
   - 緊急報告（`urgent/` 配下など） → 即時通知
4. 家老への通知は **tmux send-keys 2回方式**を厳守

## 最小構成案（Python）
- `scripts/file_watch.py` などに分離
- 設定は `config/settings.yaml` に集約

### 設定例（案）
```yaml
file_watch:
  enabled: true
  watch_dirs:
    - queue/reports
    - queue/denrei/reports
  urgent_subdir: urgent
  debounce_seconds: 2
  notify_target: "multiagent:0.0"
```

### 擬似コード
```python
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import time

class ReportHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        if not event.src_path.endswith(".yaml"):
            return
        # 例: urgent判定
        urgent = "/urgent/" in event.src_path
        notify_karo(urgent=urgent)

# Observer起動
```

## 例外対策
- **部分書き込み対策**: ファイルサイズが安定するまで短時間待つ（デバウンス）
- **誤検知対策**: 拡張子フィルタ厳守
- **安全策**: 家老は従来どおり全報告スキャン（通信ロスト対策）を維持

## 依存関係
```
pip install watchdog pyyaml
```

---

# E. 外部エージェント召喚（Python SDK）設計

## 目的
- CLI依存を減らし、**エラー処理・リトライ・タイムアウト**を標準化
- **CLIフォールバック**を維持して信頼性を担保

## 対象
- 忍び（Gemini）
- 軍師（Codex）

## 設計方針
- **YAMLを正データ**とし、SDKは実行エンジンに徹する
- 結果は従来どおり `queue/*/reports/` に保存
- 伝令経由の召喚ルールは維持

## 抽象クライアント構成
```
ExternalAgentClient
  - retry (指数バックオフ)
  - timeout
  - output validation
  - logging
  - CLI fallback
    ├─ ShinobiClient (Gemini SDK)
    └─ GunshiClient (OpenAI/Codex SDK)
```

## YAML入力スキーマ（例）
- 既存の `queue/denrei/tasks/denrei{N}.yaml` を拡張
- 追加推奨項目:
  - `engine: sdk|cli`
  - `timeout_seconds`
  - `max_retries`

### 例
```yaml
request:
  request_id: shinobi_012
  engine: sdk
  timeout_seconds: 60
  max_retries: 2
  query: |
    TypeScript 5.x breaking changes
```

## 実行フロー
1. 伝令が task YAML を読む
2. `engine` が sdk なら SDK 実行、失敗時は CLI へフォールバック
3. 結果を `queue/shinobi/reports/` or `queue/gunshi/reports/` に保存
4. 家老に send-keys で通知

## エラーハンドリング
- **SDK失敗時はCLIに自動フォールバック**
- **タイムアウト**: 失敗としてレポートに残す
- **レート制限**: 指数バックオフ

## 依存関係
```
pip install google-generativeai openai pyyaml
```

---

## 導入順序（安全ルート）
1. **ファイル監視（watchdog）**のみ導入（既存フロー非破壊）
2. **外部エージェントSDK**をCLIフォールバック付きで導入
3. 運用安定後に設定統合（settings.yaml拡張）

