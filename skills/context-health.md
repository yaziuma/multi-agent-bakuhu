# コンテキスト健康管理 詳細リファレンス

> CLAUDE.md から分離。閾値テーブルは CLAUDE.md に残存。
> 詳細戦略・テンプレート・混合戦略はこちらを参照。

## /compact カスタム指示（全エージェント必須知識）

`/compact` はカスタム指示付きで実行できる。これにより要約時に保持すべき情報を指定可能。

**構文**: `/compact <保持すべき情報の指示>`

**エージェント別テンプレート**:

| エージェント | /compact テンプレート |
|-------------|---------------------|
| **将軍** | `/compact 殿からの現在の指示、進行中プロジェクト一覧、未解決の要対応事項を必ず保持せよ` |
| **家老** | `/compact 進行中タスク一覧、各足軽の状態、未処理報告、compact回数カウンタを必ず保持せよ` |
| **足軽** | `/compact 現在のタスクID、対象ファイル、実装方針、未完了項目を必ず保持せよ` |

**重要**: カスタム指示なしの `/compact` は汎用要約となり、重要な状態情報が失われる可能性がある。**必ずカスタム指示付きで実行せよ。**

## /clear vs /compact の使い分け

| 条件 | 推奨 | 理由 |
|------|------|------|
| タスク完了後 | /clear | コンテキストを完全リセット |
| タスク途中で75%到達 | /compact（カスタム指示付き） | 作業継続のためsummary保持 |
| 同一プロジェクトの連続タスク | /compact | 前タスクのコンテキストが有用 |
| 異なるプロジェクトのタスク切替 | /clear | 前コンテキストが汚染源になる |

## 家老の混合戦略（3回compact → 1回clear）

家老は以下のサイクルでコンテキストを管理せよ：

```
compact回数カウンタ = 0 で運用開始
  │
  ▼ 60-75%到達
  │   カウンタ < 3 → /compact（カスタム指示付き）、カウンタ++
  │   カウンタ >= 3 → /clear、カウンタ = 0
  │
  ▼ 85%到達（緊急時）
  │   カウンタに関わらず /clear、カウンタ = 0
```

**コスト根拠**: 忍び調査（cmd_034）により、純粋/clear戦略（80,000トークン/サイクル）に対し混合戦略（56,000トークン/サイクル）は約30%のコスト削減効果がある。

## 家老の健康監視責任

家老は全エージェントの健康状態を監視する責任を負う。以下を実施せよ：

1. **タスク分配完了時**: 自身のコンテキストを確認し、60%超なら /compact（カスタム指示付き）
2. **足軽タスク完了時**: 足軽に /clear を送信
3. **長時間作業中の足軽**: 進捗確認時にコンテキスト状況も確認

---

## slim_yaml / コンテキスト管理ツール 運用ルール（cmd_473）

### 1. ツール役割分担表

各ツールが「何のファイルに対して何をするか」の一覧。

| ツール | 呼び出し方 | 対象ファイル | 操作内容 | アーカイブ先 |
|--------|-----------|------------|--------|------------|
| **slim_yaml.sh** + slim_yaml.py（全エージェント） | `bash scripts/slim_yaml.sh <agent_id>` | `queue/inbox/{agent_id}.yaml` | `read: true` メッセージを削除 | `queue/archive/inbox_{agent_id}_{ts}.yaml` |
| **slim_yaml.sh** + slim_yaml.py（karo専用） | `bash scripts/slim_yaml.sh karo` | `queue/shogun_to_karo.yaml` | done/cancelled cmd を削除 | `queue/archive/shogun_to_karo_{ts}.yaml` |
| **slim_yaml.sh** + slim_yaml.py（karo専用） | 〃 | `queue/tasks/*.yaml` | done/completed/cancelled タスクをアーカイブ（canonical: idle stubに戻す） | `queue/archive/tasks/` |
| **slim_yaml.sh** + slim_yaml.py（karo専用） | 〃 | `queue/reports/*.yaml`（canonical除く） | 24時間超経過かつ非アクティブなレポートをアーカイブ | `queue/archive/reports/` |
| **slim_yaml.sh** + slim_yaml.py（karo専用） | 〃 | `queue/inbox/*.yaml`（全エージェント分） | 全エージェントの `read: true` メッセージを削除 | `queue/archive/inbox_{agent}_{ts}.yaml` |
| **yaml_archive_watcher.sh** → yaml_archive_done.sh → yaml_archive_done.py | デーモン常駐（自動） | `queue/shogun_to_karo.yaml` | done/completed cmd を削除（inotifywait監視） | `logs/archive/{date}/shogun_to_karo_done_{time}.yaml` |
| **check_context.sh** | `bash scripts/check_context.sh <agent_id>` | （なし — 読み取り専用） | tmux経由で `/context` 送信、使用率% を返す | — |
| **run_compact.sh** | `bash scripts/run_compact.sh <agent_id>` | （なし — コマンド送信のみ） | tmux経由で `/compact` 送信、完了後 check_context.sh で確認 | — |

**備考**:
- slim_yaml.sh は `queue/.slim_yaml.lock`（flock）で排他制御している
- yaml_archive_watcher.sh は slim_yaml.sh のロックを使わず、yaml_archive_done.sh 経由で yaml_archive_done.py を呼ぶ
- check_context.sh / run_compact.sh はファイルを変更しない（純粋なtmux操作のみ）

---

### 2. 二重適用リスク分析

#### slim_yaml（karo） vs yaml_archive_watcher の競合

両ツールとも `queue/shogun_to_karo.yaml` の done cmd を削除する処理を持つ。

| 比較項目 | slim_yaml（karo） | yaml_archive_watcher |
|---------|-----------------|---------------------|
| トリガー | 手動（karoが明示的に実行） | 自動（shogun_to_karo.yaml 変更時） |
| ロック | `queue/.slim_yaml.lock` を使用 | ロックなし（yaml_archive_done.sh 経由で yaml_archive_done.py を実行） |
| アーカイブ先 | `queue/archive/shogun_to_karo_{ts}.yaml` | `logs/archive/{date}/shogun_to_karo_done_{time}.yaml` |
| 対象コマンド | status=done or cancelled | status=done or completed |

**同時実行シナリオ分析**:

| シナリオ | 結果 | 情報損失 |
|---------|------|---------|
| watcher が先に実行 → slim_yaml が後から実行 | done cmd はwatcherが除去済み → slim_yaml は何もアーカイブしない（idempotent） | **なし** |
| slim_yaml が先に実行 → watcher が後から実行 | done cmd はslim_yamlが除去済み → yaml_archive_done.py が「archived: 0」を出力 | **なし** |
| 同時実行（race condition） | 両方とも同じ done cmd を読み取り → 両方ともアーカイブを作成 → 最後の書き込みが残る | **なし**（同じ内容が2か所にアーカイブされるのみ） |
| 同時実行 + 第三者書き込み | slim_yaml/watcher のread後、将軍が新規 cmd を追加する間に write が発生した場合、新規 cmd が上書きで消える理論的リスクあり | **低リスク**（発生確率は極低） |

**⚠️ 注意**: 同時実行時、片方のアーカイブが重複して作成されるが、データは失われない。shogun_to_karo.yaml の active cmd は正しく保持される（両者ともアクティブなものは削除しないため）。

**⚠️ 第三者書き込みリスク（理論的）**: slim_yaml または yaml_archive_done.py がファイルを read した直後に将軍が shogun_to_karo.yaml へ新規 cmd を書き込んだ場合、その新規 cmd が slim_yaml/watcher の write によって上書きされて消失する可能性がある。ただし、slim_yaml は手動実行、yaml_archive_watcher は `close_write` イベントをトリガーとしており、将軍の書き込み完了後に watcher が起動するため、通常の運用では発生しない。技術的強制機構はなく、運用規約による制御に依存している。

**race condition の深刻度**: 低。アーカイブ先が異なるディレクトリのため基本的に競合しない。最終的に shogun_to_karo.yaml から done cmd が消えることは通常保証される。

---

### 3. 運用マトリクス（いつ・誰が・何を使うか）

| タイミング | 実行者 | 使用ツール | 備考 |
|-----------|--------|----------|------|
| **自動（常駐）** — shogun_to_karo.yaml 変更時 | インフラ（yaml_archive_watcher.sh） | yaml_archive_done.sh → yaml_archive_done.py | shutsujin_departure.sh 起動時に自動開始 |
| **karo /compact 後** | shogun または karo | `bash scripts/slim_yaml.sh karo` | shogun_to_karo + tasks + reports + 全inbox を一括スリム化 |
| **足軽 /clear 後** | karo | `bash scripts/slim_yaml.sh ashigaruN` | その足軽のinboxのみスリム化 |
| **コンテキスト確認** | 上位者（shogun→karo計測、karo→ashigaru計測） | `bash scripts/check_context.sh <agent_id>` | ファイル変更なし。測定結果をダッシュボードに反映 |
| **コンテキスト警告時（60-80%）** | 上位者 | `bash scripts/run_compact.sh <agent_id>` | /compact 送信 → 完了後に自動で check_context.sh も実行 |
| **緊急時（80%+）** | 上位者 | （/clear を直接 tmux send-keys） | run_compact.sh は使わない。即時/clear |

**禁止事項**:
- エージェント自身が slim_yaml.sh を自分に対して実行すること（上位者が実行する）
- エージェント自身が /compact を直接入力すること（run_compact.sh 経由のみ）
- slim_yaml.sh と yaml_archive_watcher を意図的に同時実行すること（自動監視に任せる）
