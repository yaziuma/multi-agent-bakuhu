# システムアーキテクチャ リファレンス

> CLAUDE.md から分離。組織構造・四層モデルの詳細参照用。

## コンテキスト保持の四層モデル

```
Layer 1: Memory MCP（永続・セッション跨ぎ）
  └─ 殿の好み・ルール、プロジェクト横断知見
  └─ 保存条件: ①gitに書けない/未反映 ②毎回必要 ③非冗長

Layer 2: Project（永続・プロジェクト固有）
  └─ config/projects.yaml: プロジェクト一覧・ステータス（軽量、頻繁に参照）
  └─ projects/<id>.yaml: プロジェクト詳細（重量、必要時のみ。Git管理外・機密情報含む）
  └─ context/{project}.md: PJ固有の技術知見・注意事項（足軽が参照する要約情報）

Layer 3: YAML Queue（永続・ファイルシステム）
  └─ queue/shogun_to_karo.yaml, queue/tasks/, queue/reports/
  └─ タスクの正データ源

Layer 4: Session（揮発・コンテキスト内）
  └─ CLAUDE.md（自動読み込み）, instructions/*.md
  └─ /clearで全消失、コンパクションでsummary化
```

### 各レイヤーの参照者

| レイヤー | 将軍 | 家老 | 足軽 |
|---------|------|------|------|
| Layer 1: Memory MCP | read_graph | read_graph | read_graph（セッション開始時・/clear復帰時） |
| Layer 2: config/projects.yaml | プロジェクト一覧確認 | タスク割当時に参照 | 参照しない |
| Layer 2: projects/<id>.yaml | プロジェクト全体像把握 | タスク分解時に参照 | 参照しない |
| Layer 2: context/{project}.md | 参照しない | 参照しない | タスクにproject指定時に読む |
| Layer 3: YAML Queue | shogun_to_karo.yaml | 全YAML | 自分のashigaru{N}.yaml |
| Layer 4: Session | instructions/shogun.md | instructions/karo.md | instructions/ashigaru.md |

## 階層構造

```
上様（人間 / The Lord）
  │
  ▼ 指示
┌──────────────┐
│   SHOGUN     │ ← 将軍（プロジェクト統括）
│   (将軍)     │
└──────┬───────┘
       │ YAMLファイル経由
       ▼
┌──────────────┐
│    KARO      │ ← 家老（タスク管理・分配）
│   (家老)     │
└──────┬───────┘
       │
 ┌─────┴─────────────────┐
 │                       │
 ▼                       ▼
┌───┬───┬───┐         ┌───┬───┐         ┌──────┐   ┌──────┐
│A1 │...│A8 │         │D1 │D2 │ ──────→ │ 忍び │   │ 軍師 │
└───┴───┴───┘         └───┴───┘         └──────┘   └──────┘
    足軽                 伝令              外部エージェント
   (実装)              (連絡係)          (諜報/戦略参謀)
```

## プロジェクト管理

shogunシステムは自身の改善だけでなく、**全てのホワイトカラー業務**を管理・実行する。
プロジェクトの管理フォルダは外部にあってもよい（shogunリポジトリ配下でなくてもOK）。

```
config/projects.yaml       # どのプロジェクトがあるか（一覧・サマリ）
projects/<id>.yaml          # 各プロジェクトの詳細（クライアント情報、タスク、Notion連携等）
```

- `config/projects.yaml`: プロジェクトID・名前・パス・ステータスの一覧のみ
- `projects/<id>.yaml`: そのプロジェクトの全詳細（クライアント、契約、タスク、関連ファイル等）
- プロジェクトの実ファイル（ソースコード、設計書等）は `path` で指定した外部フォルダに置く
- `projects/` フォルダはGit追跡対象外（機密情報を含むため）
