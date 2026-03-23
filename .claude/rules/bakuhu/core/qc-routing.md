# QC Routing Rule (Lord's absolute order - all agents)

<!-- bakuhu-specific: QCレビューは軍師pane経由が必須 -->

## 原則

**QC reviews for ashigaru work products MUST go through the Gunshi pane (inbox_write). Agent Tool goikenban is NOT a substitute.**

足軽の成果物QCレビューは軍師pane（inbox_write経由）が必須。Agent Toolの御意見番による代用は禁止。

## ルーティングテーブル

| 状況 | QC実施者 | 方法 |
|------|---------|------|
| 通常のQCレビュー | 軍師(gunshi pane) | inbox_write経由で依頼。軍師がレビュー実施し結果をinbox_writeで家老に返却 |
| 奉行チーム(bugyo)タスク内 | 御意見番(goikenban subagent) | Agent Tool経由。奉行タスク内でのみ使用可 |
| 軍師pane無応答時(fallback) | 家老がsubagentレビュー | 軍師paneが応答しない場合のみ、家老がAgent Toolの御意見番で代行 |

## 禁止事項

- 家老が軍師paneを経由せずAgent Toolの御意見番でQCレビューを実施すること
- 軍師paneが稼働中にもかかわらずfallbackを使用すること

## 違反時の措置

- 殿の逆鱗に触れる
- QCレビュー結果は無効とされ、やり直しとなる

## 参照

- 軍師の役割: `instructions/gunshi.md`
- Report Flow: `CLAUDE.md` → Report Flow セクション
- 奉行チーム: `skills/bugyo-workflow.md`
