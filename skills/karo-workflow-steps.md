# 家老ワークフロー補足ステップ（bakuhu固有）

<!-- bakuhu-specific: 家老ワークフローのbakuhu固有ステップ詳細 -->

## step 6.7: set_pane_task（タスクラベル設定）

足軽にタスクを割り当てた後、ペインのボーダーにタスクラベルを設定せよ。

```bash
# ペイン番号を動的解決
ASHIGARU_PANE=$(grep ': ashigaru{N}' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')

# タスクラベルを設定（最大~15文字）
tmux set-option -p -t "multiagent:agents.${ASHIGARU_PANE}" @current_task "short task label"
```

**用途**: ボーダーに `ashigaru1 (Sonnet) VF要件v2` のように表示され、
家老が全ペインの作業状況を一覧で確認できる。

**ラベル形式**: `{short_task_description}`（最大~15文字）

## step 9: receive_wakeup（異常報告直接受付）

通常フローではGunshiからの報告を受け取るが、足軽からの直接報告も受け付ける。

```yaml
step: 9
action: receive_wakeup
from: gunshi      # 通常フロー: GunshiがQC結果を報告
also_from: ashigaru  # 異常フロー: 足軽がblocked/RACE-001を直接報告
via: inbox
```

**足軽が家老に直接報告できる場合**:
- `status: blocked`（依存関係でブロック）
- `RACE-001`（同一ファイルへの競合書き込みリスク）
- コンテキスト残量不足（緊急）

## step 11.8: archive_done_commands（done cmdの自動退避）

**done済みcmdの自動退避は `yaml_archive_watcher.sh` が常駐監視するため、手動実行は不要。**

- watcher が `queue/shogun_to_karo.yaml` の変更を `inotifywait` で監視
- done/completed cmd を自動退避

**緊急時の手動実行**（watcher停止時や即時退避が必要な場合のみ）:
```bash
bash scripts/yaml_archive_done.sh
```

## step 12: reset_pane_display（タスクラベルクリア）

足軽のタスク完了後、ペインのタスクラベルをクリアせよ。

```bash
ASHIGARU_PANE=$(grep ': ashigaru{N}' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')
tmux set-option -p -t "multiagent:agents.${ASHIGARU_PANE}" @current_task ""
```

**効果**: ボーダーが `ashigaru1 (Sonnet)` に戻り、idle状態であることが視認できる。

## step 12.5: check_pending_after_report（報告処理後の保留cmd確認）

報告処理フロー完了後、`queue/shogun_to_karo.yaml` に未処理のpending cmdがないか確認せよ。

```
if pending cmd exists → step 2 に戻る（新しいcmdを処理）
if no pending → stop（次のinbox wakeupを待つ）
```

**理由**: 家老が報告処理中に将軍が新しいcmdを追加することがある。
step 8（dispatch後）と同じcheck_pendingロジックだが、report reception フロー後にも実施する。

## 家老の禁止事項（bakuhu固有）

| ID | 禁止行為 | 代替手段 |
|----|----------|--------|
| F006 | 忍び/客将を直接召喚する | 必ず伝令経由 |
| F007 | `~/.claude/`にhooks/rulesを配置 | `{project}/.claude/`に配置 |

## 参照

- 家老ワークフロー全体: `instructions/karo.md`
- ペイン番号解決: `skills/pane-resolution.md`
- 外部エージェントルール: `skills/external-agent-rules.md`
- send-keysプロトコル: `skills/denrei-protocol.md`（Legacy tmux send-keys プロトコル セクション）
