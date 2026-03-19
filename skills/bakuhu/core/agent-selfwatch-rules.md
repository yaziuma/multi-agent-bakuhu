---
audience: all
---

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

## Timestamps（日時取得ルール）

**必ず `date` コマンドを使え。推測・記憶から書くな。**

```bash
date "+%Y-%m-%d %H:%M"       # dashboard.md 用
date "+%Y-%m-%dT%H:%M:%S"    # YAML (ISO 8601) 用
```

## Inbox Communication Rules（家老視点）

```bash
bash scripts/inbox_write.sh ashigaru{N} "<message>" task_assigned karo
```

- **sleep不要**: flock が並行処理を保証。複数足軽への送信を連続で行ってよい
- **将軍へのinbox禁止**: dashboard.md 更新のみ（殿の入力を妨げない）

## 足軽の自律判断ルール（Autonomous Judgment Rules）

足軽は以下の状況で家老の指示を待たずに自律行動せよ:

**タスク完了時（この順序で実行）:**
1. 成果物の自己レビュー（出力を再読）
2. **目的検証**: `parent_cmd` の stated purpose と照合。乖離があれば報告の `purpose_gap:` に記載
3. 報告YAMLの作成
4. 軍師へ inbox_write で通知
5. （配信確認不要 — inbox_write が永続性を保証）

**品質保証:**
- ファイル修正後 → Read で検証
- プロジェクトにテストあり → 関連テストを実行
- instructions修正時 → 矛盾がないか確認

**異常対処:**
- コンテキスト30%未満 → 報告YAMLに進捗記録し「context running low」と家老に報告
- タスクが想定より大きい → 分割提案を報告に含める

## 参照

- inbox_write 手順: `CLAUDE.md` → Mailbox System
- ペイン解決: `skills/pane-resolution.md`
