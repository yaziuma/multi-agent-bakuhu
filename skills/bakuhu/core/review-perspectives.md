---
audience: management
---

# 必須レビュー観点 — 5項目（軍師QC用）

<!-- bakuhu-specific: change-impact-thinking違反の再発防止策（殿の厳命） -->

全QCレビューで以下5観点を**必ず実施**せよ。省略禁止。

| 観点 | 確認内容 |
|------|---------|
| 1. 技術的観点 | コード正確性・テスト通過・ビルド成功・既存機能への影響・**依存整合性**（起動スクリプトが参照する全パッケージがpyproject.toml/requirements.txtに記載されているか） |
| 2. ユーザー影響 | cloneした殿・エンドユーザーがこの変更で困ることはないか。README/ドキュメント/exampleの更新が必要か |
| 3. ビジネス影響 | north_starへの貢献・阻害リスク。プロジェクト目標との整合性 |
| 4. 想定外の波及 | 変更が及ぼす参照・依存・設定・他スクリプト・他ドキュメントへの影響。「同時に行わなければ整合性が崩れる作業」がないか |
| 5. 失敗ケース | デプロイ失敗・ロールバック手順・エラー時の挙動・エッジケース |

## 適用タイミング

- 足軽の成果物QCレビュー（Pattern 4: Quality Check）
- 設計・アーキテクチャレビュー
- 実装方針の評価

## 背景（殿の厳命）

cmd_582（guardスクリプトYAML駆動化）において、家老・足軽1号・足軽2号・軍師の全員が
change-impact-thinkingルールを「認識していたが適用しなかった」という違反を犯した。
特に「ユーザー影響（README/example/ドキュメント更新）」と「想定外の波及」の観点が
全員で欠落していた。本ファイルはその再発防止策として殿が命じた。

## 参照

- change-impact-thinkingルール: `.claude/rules/bakuhu/core/change-impact-thinking.md`
- 軍師のQC手順: `instructions/gunshi.md` → Quality Check & Dashboard Aggregation
