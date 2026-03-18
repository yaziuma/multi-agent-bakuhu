# Agent Self-Watch Phase Rules

<!-- bakuhu-specific: cmd_107 で確立したイベント駆動運用ルール -->

## 三フェーズ構成

bakuhu の inbox 配信システムは3フェーズで構成されている。

| Phase | 動作 | ルール |
|-------|------|--------|
| Phase 1 | watcher が `process_unread_once` / inotify + timeout fallback を前提に運用 | 通常nudgeあり |
| Phase 2 | 通常nudge停止（`disable_normal_nudge`）を前提に、割当後の配信確認をnudge依存で設計しない | nudge非依存 |
| Phase 3 | `FINAL_ESCALATION_ONLY` で send-keys が最終復旧限定 | 通常配信はinbox YAMLを正本として扱う |

## sleep 禁止ルール

**家老のコンテキストでの `sleep` は絶対禁止**（2026-02-06 24分フリーズ事案より）。

家老がブロックされると軍全体が停止する。

```
❌ 禁止パターン:
  cmd_008 dispatch → sleep 30 → capture-pane → check status → sleep 30 ...

✅ 正しいパターン（イベント駆動）:
  cmd_008 dispatch → inbox_write ashigaru → stop (await inbox wakeup)
  → ashigaru completes → inbox_write karo → karo wakes → process report
```

## tmux capture-pane 禁止ルール

家老は **ステータス確認のために `tmux capture-pane` を使用してはならない**。

| 禁止 | 代替 |
|------|------|
| `tmux capture-pane` でステータス確認 | 報告YAML（`queue/reports/ashigaru{N}_report.yaml`）を直接Readする |
| ポーリングループ | inbox_write による wake-up シグナル待機 |

**例外**: send-keys 送信先の確認（ペイン番号ズレ検知）のみ許可。

## Dispatch-then-Stop パターン（必須）

タスクを振り終えたら止まれ。次のアクションを待つのではなく、inbox wakeup を待て。

```
1. 全 pending cmd を列挙
2. 各cmdを分解 → YAML書き込み → inbox_write → 次のcmdへ（sleep不要）
3. 全cmd処理完了 → stop（inbox wakeupを待つ）
4. wakeup受信 → 報告スキャン → 処理 → pending確認 → stop
```

## 配信品質の確認方法

`watcher_status.yaml` の以下フィールドを参照して判断する:

- `unread_latency_sec` — 未読メッセージの経過時間
- `read_count` — 処理済みメッセージ数
- `estimated_tokens` — 推定トークン消費量

## 参照

- inbox_write 手順: `CLAUDE.md` → Mailbox System
- ペイン解決: `skills/pane-resolution.md`
