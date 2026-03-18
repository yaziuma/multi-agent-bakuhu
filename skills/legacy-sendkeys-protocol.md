# Legacy tmux send-keys Protocol (bakuhu denrei/shinobi)

<!-- bakuhu-specific: 伝令・忍び向けのlegacy send-keys通信プロトコル -->

## 適用範囲

**通常のエージェント間通信は inbox_write.sh を使え。**
本プロトコルは **denrei（伝令）/ shinobi（忍び）連携専用** のlegacyプロトコルである。

## ポーリング禁止

send-keys を使ったポーリングループは **API コスト観点から絶対禁止**。

```
❌ 禁止:
  cmd dispatch → sleep 30 → capture-pane → check status → sleep 30 → ...

✅ 正しいパターン（イベント駆動）:
  cmd dispatch → inbox_write → stop (await response)
  → response received → process → next step
```

## 2回分離送信ルール（必須）

send-keys は必ず **2回の独立したBash呼び出し** に分離せよ。

```bash
# Bash呼び出し 1: メッセージ送信
tmux send-keys -t multiagent:0.0 'メッセージ内容'

# Bash呼び出し 2: Enter送信
tmux send-keys -t multiagent:0.0 Enter
```

**1回の呼び出しでメッセージとEnterを一緒に送ることは禁止。**
（paneの状態によってEnterが欠落するリスクがある）

## 報告フロー（割り込み防止）

| 方向 | 方法 | 制約 |
|------|------|------|
| 足軽 → 家老 | 報告YAML + inbox_write（または send-keys for legacy） | — |
| 家老 → 将軍/殿 | dashboard.md 更新のみ | **将軍へのinbox送信は禁止** |
| 上位 → 下位 | YAML + inbox_write（または send-keys for legacy） | — |

**将軍へのinbox送信が禁止の理由**: 殿の入力を妨げないため。

## send-keys 使用が許可される場面

1. 伝令（denrei）へのタスク指示
2. 忍び（shinobi）へのタスク指示
3. `/clear` コマンドの強制送信（エスカレーション時）
4. `/model` コマンドのモデル切り替え

**それ以外の用途での send-keys 使用は禁止**。

## 関連

- 通常の通信方式: `CLAUDE.md` → Mailbox System
- 外部エージェントルール: `skills/external-agent-rules.md`
- 伝令プロトコル詳細: `skills/denrei-protocol.md`
