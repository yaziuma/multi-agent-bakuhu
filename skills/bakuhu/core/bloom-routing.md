---
audience: management
---

# Bloom Routing（タスク難易度ルーティング）

<!-- bakuhu-specific: Bloom's Taxonomy に基づく動的モデルルーティング -->

## Bloom Level 定義

| Level | 分類 | 説明 | 例 |
|-------|------|------|-----|
| L1 | 記憶 | コピー、移動、単純置換 | ファイルのコピー、変数名の一括置換 |
| L2 | 理解 | 整理、分類、フォーマット変換 | YAML整形、ドキュメント構造整理 |
| L3 | 機械的適用 | 定型修正、テンプレ埋め、frontmatter一括修正 | 定型コード修正、テンプレート展開 |
| L4 | 創造的適用 | 記事執筆、コード実装（判断・創造性を伴う） | 新機能実装、設計に沿ったコード作成 |
| L5 | 分析・評価 | QC、設計レビュー、品質判定 | コードレビュー、アーキテクチャ評価 |
| L6 | 創造 | 戦略設計、新規アーキテクチャ、要件定義 | システム設計、技術選定戦略 |

**判断基準**: 「創造性・判断が要るか？」→ YES = L4以上、NO = L3以下

## bloom_routing 設定値

`config/settings.yaml` の `bloom_routing` フィールドで制御する。

| 設定値 | 動作 |
|--------|------|
| `manual` | 家老が手動判断。bloom_level は参考情報として付与するが、ルーティングは変更しない |
| `auto` | L4-L6 タスクを自動で軍師にルーティング。L1-L3 は足軽に割当 |
| `off` | スキップ（bloom_level は付与するがルーティングに使用しない） |

## auto モード時のルーティング

| Bloom Level | ルーティング先 | 処理方法 |
|-------------|--------------|---------|
| L1-L3 | 足軽 | 従来通り直接割当 |
| L4-L5 | 軍師 → 足軽 | 軍師に戦略分析を依頼してから足軽に割当 |
| L6 | 軍師 → タスク分解 → 足軽 | 軍師の報告に基づいてタスク分解 |

## manual モード時の判断

bloom_level は付与されるが、ルーティングは家老の判断に委ねる。軍師への依頼は家老が必要と判断した場合のみ。

## タスクYAMLへの記載

全タスクYAMLに `bloom_level` フィールドを付与すること（省略禁止）。

```yaml
task:
  task_id: subtask_xxx
  bloom_level: L4   # L1-L6 で指定
  description: |
    ...
```

## Eat the Frog 連携

**Frog = 最難タスク**。cmd受信・分解後に bloom L5-L6 の最難 subtask を `today.frog` に設定し優先割当する。

- **設定タイミング**: cmd受信後の分解時。1日1件のみ（既設定なら上書き禁止）
- **優先度**: Frog タスクを最初に割り当てる
- **完了時**: 🐸通知 → `today.frog` を `""` にリセット

## Opus 必須基準（OC）テーブル

**デフォルトは足軽1-4（Sonnet）。以下の OC に2件以上該当する場合のみ足軽5-8（Opus）を使用。**

| OC | 基準 | 例 |
|----|------|-----|
| OC1 | 複雑なアーキテクチャ/システム設計 | 新規モジュール設計、通信プロトコル設計 |
| OC2 | 多ファイルリファクタリング（5+ファイル） | システム全体の構造変更 |
| OC3 | 高度な分析・戦略立案 | 技術選定の比較分析、コスト試算 |
| OC4 | 創造的・探索的タスク | 新機能のアイデア出し、設計提案 |
| OC5 | 長文の高品質ドキュメント | README全面改訂、設計書作成 |
| OC6 | 困難なデバッグ調査 | 再現困難なバグ、マルチスレッド問題 |
| OC7 | セキュリティ関連実装・レビュー | 認証、暗号化、脆弱性対応 |

**判断に迷う場合（OC 1件のみ）**: まず Sonnet 足軽に投入。品質不足なら Opus 足軽に再投入。

## 動的切替の原則

| 足軽 | デフォルト | 切替方向 | 切替条件 |
|------|-----------|---------|---------|
| 足軽1-4 | Sonnet Thinking | → Opus に**昇格** | OC基準2件+ かつ Opus足軽が全て使用中 |
| 足軽5-8 | Opus Thinking | → Sonnet に**降格** | OC基準に2件以上該当しない軽タスク |

**重要**: 足軽5-8に軽タスクを振る際は必ず Sonnet に降格してから割り当てよ。

## `/model` コマンドによる切替手順（3ステップ）

```bash
# Step 1: モデル切替コマンドを送信
tmux send-keys -t multiagent:0.{N} '/model <新モデル>'
# Step 2: Enter を送信
tmux send-keys -t multiagent:0.{N} Enter
# Step 3: tmux ボーダー表示を更新
tmux set-option -p -t multiagent:0.{N} @model_name '<新表示名>'
```

**表示名対応テーブル:**

| `/model` 引数 | `@model_name` 表示名 |
|---------------|---------------------|
| `opus` | `Opus Thinking` |
| `sonnet` | `Sonnet Thinking` |

**例（足軽{N}をSonnetに降格）:**
```bash
ASHIGARU_PANE=$(grep ': ashigaru{N}' config/pane_role_map.yaml | awk '{print $1}' | tr -d ':')
tmux send-keys -t "$ASHIGARU_PANE" '/model sonnet'
tmux send-keys -t "$ASHIGARU_PANE" Enter
tmux set-option -p -t "$ASHIGARU_PANE" @model_name 'Sonnet Thinking'
```

## 参照

- 軍師ディスパッチ手順: `instructions/karo.md` → Gunshi Dispatch Procedure
- モデル選定基準: `instructions/karo.md` → 足軽モデル選定・動的切替
