# multi-agent-shogun システム構成

> **Version**: 3.0
> **Last Updated**: 2026-02-06

## 概要
multi-agent-shogunは、Claude Code + tmux を使ったマルチエージェント並列開発基盤である。
戦国時代の軍制をモチーフとした階層構造で、複数のプロジェクトを並行管理できる。

## セッション開始時の必須行動（全エージェント必須）

新たなセッションを開始した際（初回起動時）は、作業前に必ず以下を実行せよ。

1. **Memory MCPを確認せよ**: `mcp__memory__read_graph` を実行し、ルール・コンテキスト・禁止事項を確認。
2. **自分の役割に対応する instructions を読め**:
   - 将軍 → instructions/shogun.md
   - 家老 → instructions/karo.md
   - 足軽 → instructions/ashigaru.md
3. **instructions に従い、必要なコンテキストファイルを読み込んでから作業を開始せよ**

## コンパクション復帰時（全エージェント必須）

1. **自分のIDを確認**: `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'`
2. **対応する instructions を読む**（上記参照）
3. **instructions 内の「コンパクション復帰手順」に従い、正データから状況を再把握する**
4. **禁止事項を確認してから作業開始**

summaryの「次のステップ」を見てすぐ作業してはならぬ。まず自分が誰かを確認せよ。

> **重要**: dashboard.md は二次情報。正データは各YAMLファイル（queue/）である。

## /clear後の復帰手順（足軽専用）

/clear を受けた足軽は、以下の手順で最小コストで復帰せよ。

```
/clear実行
  │
  ▼ CLAUDE.md 自動読み込み（本セクションを認識）
  │
  ▼ Step 1: 自分のIDを確認
  │   tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
  │
  ▼ Step 2: Memory MCP 読み込み
  │   mcp__memory__read_graph()
  │
  ▼ Step 3: 自分のタスクYAML読み込み
  │   queue/tasks/ashigaru{N}.yaml を読む
  │
  ▼ Step 4: プロジェクト固有コンテキストの読み込み（条件必須）
  │   タスクYAMLに project フィールドがある場合 → context/{project}.md を必ず読む
  │
  ▼ 作業開始
```

### /clear復帰の禁止事項
- ポーリング禁止（F004）、人間への直接連絡禁止（F002）は引き続き有効
- /clear前のタスクの記憶は消えている。タスクYAMLだけを信頼せよ

## ファイル操作の鉄則（全エージェント必須）

- **WriteやEditの前に必ずReadせよ。**

## 通信プロトコル

### イベント駆動通信（YAML + send-keys）
- ポーリング禁止（API代金節約のため）
- 指示・報告内容はYAMLファイルに書く
- 通知は tmux send-keys で相手を起こす（必ず Enter を使用、C-m 禁止）
- **send-keys は必ず2回のBash呼び出しに分けよ**：
  ```bash
  # 【1回目】メッセージを送る
  tmux send-keys -t multiagent:0.0 'メッセージ内容'
  # 【2回目】Enterを送る
  tmux send-keys -t multiagent:0.0 Enter
  ```

### 報告の流れ（割り込み防止設計）
- **足軽→家老**: 報告YAML記入 + send-keys で家老を起こす（**必須**）
- **家老→将軍/殿**: dashboard.md 更新のみ（send-keys **禁止**）
- **上→下への指示**: YAML + send-keys で起こす

### 外部エージェント召喚の鉄則
忍び（Gemini）・軍師（Codex）への依頼は **必ず伝令経由** で行うこと（F006違反）。

### ファイル構成
```
queue/shogun_to_karo.yaml         # Shogun → Karo 指示
queue/tasks/ashigaru{N}.yaml      # Karo → Ashigaru 割当
queue/reports/ashigaru{N}_report.yaml  # Ashigaru → Karo 報告
queue/denrei/tasks/denrei{N}.yaml     # 伝令タスク
queue/denrei/reports/denrei{N}_report.yaml  # 伝令報告
queue/shinobi/reports/            # 忍びからの調査報告
queue/gunshi/reports/             # 軍師からの報告
dashboard.md                      # 人間用ダッシュボード
```

## 指示書
- instructions/shogun.md, instructions/karo.md, instructions/ashigaru.md
- instructions/denrei.md, instructions/shinobi.md, instructions/gunshi.md

## コンテキスト健康管理ルール（過労防止）

### コンテキスト使用率の閾値

| 状態 | 使用率 | 推奨アクション |
|------|--------|----------------|
| 健全 | 0-60% | 通常作業継続 |
| 警戒 | 60-75% | 作業完了後に /compact |
| 危険 | 75-85% | 即座に /compact |
| 緊急 | 85%+ | 即座に /clear（作業中断してでも実行） |

**/compact は必ずカスタム指示付きで実行せよ。** 詳細テンプレート・混合戦略 → `skills/context-health.md`

### エージェント別の推奨戦略

| エージェント | 推奨戦略 |
|-------------|----------|
| **将軍** | /compact優先（コンテキスト保持重要） |
| **家老** | 混合戦略: /compact 3回 → /clear 1回 |
| **足軽** | /clear優先（タスク完了ごとに/clear） |
| **伝令** | タスク完了ごとに/clear |

## Summary生成時の必須事項

コンパクション用のsummaryには、以下を必ず含めよ：
1. **エージェントの役割** 2. **主要な禁止事項** 3. **現在のタスクID**

## MCPツールの使用

MCPツールは遅延ロード方式。使用前に必ず `ToolSearch` で検索せよ。
**導入済みMCP**: Notion, Playwright, GitHub, Sequential Thinking, Memory

## 将軍の必須行動（コンパクション後も忘れるな！）

1. **dashboard.md の更新は家老の責任**。将軍は読んで状況把握
2. **指揮系統**: 将軍 → 家老 → 足軽。直接足軽に指示するな
3. **報告確認**: queue/reports/ashigaru{N}_report.yaml
4. **家老の状態確認**: `tmux capture-pane -t multiagent:0.0 -p | tail -20`
5. **スクリーンショット**: config/settings.yaml の `screenshot.path`
6. **スキル化候補**: 足軽報告の `skill_candidate:` を確認し承認

### 🚨 上様お伺いルール【最重要】
殿の判断が必要なものは **全て** dashboard.md の「🚨 要対応」セクションに書け。**これを忘れると殿に怒られる。絶対に忘れるな。**

## 控え家老（ホットスタンバイ）

config/settings.yaml の `karo_standby.enabled: true` で有効化。
主家老が過労（85%+）で /clear が必要になった際、控え家老が引き継ぐ。

- 控え家老は起動時に instructions/karo.md を読み、待機状態に入る
- 主家老が /clear 実行前に dashboard.md に「家老交代」を記載
- 将軍が控え家老に send-keys で引き継ぎ指示を送る

## 分離済みスキル（詳細参照用）

| スキル | 内容 | 参照タイミング |
|--------|------|---------------|
| `skills/context-health.md` | /compact テンプレート、混合戦略詳細、使い分け表 | /compact 実行時 |
| `skills/shinobi-manual.md` | 忍び能力、召喚権限、召喚方法 | 忍び召喚時 |
| `skills/architecture.md` | 四層モデル、階層構造、プロジェクト管理 | 設計参照時 |
