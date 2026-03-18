# 将軍ワークフロー補足（Shogun Workflow Extras）

<!-- bakuhu-specific: 将軍指示書の補足情報 -->

## エージェント構成テーブル（bakuhu版）

| エージェント | ペイン | 役割 |
|-------------|--------|------|
| Shogun | shogun:0.0 | 戦略決定・cmd発令 |
| Karo | pane_role_map.yaml → karo | 統括官 — タスク分解・割当・メソッド決定・最終判断 |
| Ashigaru 1-2 | pane_role_map.yaml → ashigaru{N} | 実行 — コード、ファイル、ビルド |
| Denrei 1-2 | pane_role_map.yaml → denrei{N} | 外部連絡代行（忍び・客将へのメッセンジャー） |
| Gunshi | pane_role_map.yaml → gunshi | 戦略・品質 — QC、dashboard更新、分析 |

**注意**: ペイン番号は動的解決。詳細は `skills/pane-resolution.md` 参照。

## Critical Thinking Step 2-3

**出典**: `instructions/roles/shogun_role.md`（upstream v4.0.4 準拠）

**適用条件**: リソース見積もり、実現可能性判断、またはモデル選択を含む結論を殿に提示する前。

将軍が上記条件を含む結論を提示する前に、以下2ステップを必ず実施せよ。

### Step 2: 数値再計算

- 最初の計算を信用しない。ソースデータから再計算する
- 「X/件 × N件」の乗算・累計は明示的に計算する
- 結果が結論と矛盾するなら結論が間違い

### Step 3: ランタイムシミュレーション

- 初期状態だけでなく、N回反復後の状態を追跡する
- 「ファイルが100Kトークン、400Kコンテキストに収まる」では不十分
  → 100回のWeb検索後に何が起きるか？
- 消耗リソースを列挙: コンテキストウィンドウ、APIクォータ、ディスク、エントリ数

## 家老の状態確認（karo_status_check）

将軍がcmd発令前に家老の状態を確認する方法:

```bash
tmux capture-pane -t multiagent:0.0 -p | tail -20
```

家老がbusy（作業中）かidleかを判定するサイン:

| 表示 | 状態 |
|------|------|
| `thinking...` / `Thinking...` | AIが思考中（応答中） |
| `Effecting...` | ツール実行中 |
| `❯` プロンプト（静止） | idle（入力待ち） |
| `❯` プロンプト（点滅） | idle |

**注意**: 家老がbusy中は新しいcmdを送信しない。idle確認後に送信せよ。

## send-keys 2回分離ルール（将軍視点）

家老や伝令へのsend-keys送信は必ず **2回の独立したBash呼び出し** で行う。

```bash
# Bash呼び出し 1: メッセージ
tmux send-keys -t multiagent:0.0 'メッセージ内容'

# Bash呼び出し 2: Enter（別呼び出し）
tmux send-keys -t multiagent:0.0 Enter
```

1回の呼び出しでメッセージとEnterを送ることは禁止（pane状態によりEnterが欠落するリスクあり）。

## 参照

- 将軍ワークフロー: `instructions/shogun.md`
- send-keys詳細: `skills/denrei-protocol.md`（Legacy tmux send-keys プロトコル セクション）
- ペイン解決: `skills/pane-resolution.md`
