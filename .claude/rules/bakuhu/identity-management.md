# Identity Management Rule (bakuhu)

<!-- bakuhu-specific: @agent_id による identity 管理ルール -->

## @agent_id が唯一のidentity源

**全エージェント共通**: identity は tmux pane 変数 `@agent_id` からのみ読み取る。

```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```

この値が自分のidentity。以下よりも **@agent_id が最優先**:
- MEMORY.md の記述
- Memory MCP graph の記述
- 会話履歴・compaction summary

## @agent_id の書き込み禁止

**identityのWRITEは原則禁止**。`shutsujin_departure.sh` が起動時に正しく設定済み。

**理由（2026-02-20検出バグ）**: MEMORY.md・Memory graph は全セッション共有のため、
identity情報を書き込むと全エージェントが同一ロールを自称する致命的バグを引き起こす。

## 修復手順（@agent_id が空または不正値の場合のみ）

```bash
# Step 1: ファイル名からN番を判定
# queue/tasks/ashigaru{N}.yaml のNを確認

# Step 2: tmux変数を修復
tmux set-option -p -t "$TMUX_PANE" @agent_id ashigaru{N}
```

## Session Start での確認順序

1. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` → identity確定
2. 空/不正値の場合のみ上記修復手順を実行
3. MEMORY.md や Memory graph の内容は identity 判定に使用しない

## 参照

- Session Start手順: `CLAUDE.md` → Session Start / Recovery
- /clear Recovery: `CLAUDE.md` → /clear Recovery (ashigaru only)
