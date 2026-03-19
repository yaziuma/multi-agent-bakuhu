---
audience: management
---

# スキル化候補フロー

<!-- bakuhu-specific: 汎用パターンをスキルファイル化するプロセス -->

## フロー概要

```
足軽が汎用パターンを発見
  ↓
報告YAMLに skill_candidate フィールドを記載
  ↓
家老が受信時に確認・重複チェック
  ↓
dashboard.md スキル化候補セクションに追加
  ↓
🚨 要対応 に要約を追加（殿の承認待ち）
  ↓
殿が承認 → 将軍が設計書を作成 → 足軽が実装
```

## 足軽の役割

汎用パターンを発見したら報告YAML に記載すること（自分でスキルファイルを作成するな）。

**判断基準**:
- 同じパターンを2回以上繰り返した
- 他のタスクでも使えると判断できる
- 明確なルールとして言語化できる

**報告形式**:
```yaml
skill_candidate:
  name: "スキル名"
  description: "どんな問題を解決するか（1-2文）"
  pattern: "具体的なパターンや手順"
```

## 家老の役割

足軽報告受信時に `skill_candidate` フィールドを確認:

1. **重複チェック**: `skills/bakuhu/core/` ディレクトリに既存の類似スキルがないか確認
2. **dashboard.md 更新**: `スキル化候補` セクションに追加
3. **要対応追加**: 🚨 要対応 セクションに要約（殿の承認が必要）

## 将軍の役割

スキル化候補一覧をダッシュボードで確認し、承認の場合:
- 設計ドキュメントを作成
- 家老経由で足軽にスキルファイル実装を指示

**新スキル作成ルール（配置基準）**:

| 配置先 | 基準 | 例 |
|--------|------|-----|
| `skills/bakuhu/core/` | 運営必須スキル（全エージェントが参照する可能性あり） | identity-management, denrei-protocol 等 |
| `skills/bakuhu/extra/` | bakuhu追加スキルだが運営必須外（補助・参考情報） | webui-inspection-checklist 等 |
| `skills/generated/` | PJ由来自動生成（skill-creator産） | プロジェクト固有の自動生成スキル |

**frontmatter必須**: 新スキルファイル作成時は必ず `audience` フィールドを付与すること

```markdown
---
audience: <management|worker|all>
---
```

- management: 将軍/家老向け（意思決定・管理・戦略系）
- worker: 足軽/軍師向け（実作業手順・プロトコル系）
- all: 全員必読（システム全体に影響するルール）

## 参照

- ダッシュボード管理: `skills/bakuhu/core/dashboard-rules.md`
- 足軽報告フォーマット: `instructions/ashigaru.md`
