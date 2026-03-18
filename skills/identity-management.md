# Identity Management（@agent_id ルール）

<!-- bakuhu-specific: tmux @agent_id による identity 管理 -->

## 原則：@agent_id が唯一のidentity源

**全エージェント共通**: identity は tmux pane 変数 `@agent_id` からのみ読み取る。

```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```

この値が自分のidentity。以下よりも **@agent_id が最優先**:
- `MEMORY.md` の記述
- Memory MCP graph の記述
- 会話履歴・compaction summary

**理由（2026-02-20検出バグ）**:
MEMORY.md・Memory graph は全セッション共有のため、identity情報を書き込むと
全エージェントが同一ロールを自称する致命的バグを引き起こす。

## @agent_id の書き込み禁止

**identityのWRITEは原則禁止**。`shutsujin_departure.sh` が起動時に正しく設定済み。

## Session Start での読み取り手順

```
Step 1: tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' を実行
Step 2: 値を確認
  - 正常値（例: ashigaru2, karo, gunshi）→ そのままidentityとして使用
  - 空または不正値 → 下記修復手順を実行
```

## 修復手順（空または不正値の場合のみ）

```bash
# Step 1: ファイル名からN番を判定
# queue/tasks/ashigaru{N}.yaml のNを確認（タスクファイル名から読む）

# Step 2: tmux変数を修復
tmux set-option -p -t "$TMUX_PANE" @agent_id ashigaru{N}
```

## /clear Recovery での適用

/clear後の復帰でも同じ手順を使う（CLAUDE.md の /clear Recovery 参照）:

```
Step 1: tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
        → 空または不正値の場合のみ: queue/tasks/ashigaru{N}.yaml のファイル名からN判定
          → tmux set-option -p -t "$TMUX_PANE" @agent_id ashigaru{N} で修復
```

## 自分のファイルの特定

```
# ashigaru{N} の場合:
queue/tasks/ashigaru{N}.yaml          ← 自分のタスクファイル（他は絶対読むな）
queue/reports/ashigaru{N}_report.yaml ← 自分の報告ファイル（他は絶対書くな）
```

**重要**: `@agent_id` が `ashigaru3` なら、N=3 のファイルだけを操作する。
ペイン番号が変わっても @agent_id は変わらない（shutsujin_departure.sh が保証）。

## 参照

- Session Start手順全体: `CLAUDE.md` → Session Start / Recovery
- /clear Recovery手順: `CLAUDE.md` → /clear Recovery (ashigaru only)
- ペイン番号解決: `skills/pane-resolution.md`
