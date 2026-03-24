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

## 家老の完了報告ゲート（将軍が却下する条件）

**将軍は以下の条件を満たさない完了報告を即座に却下する。**

| 必須要素 | 説明 |
|---------|------|
| 軍師QC結果 | `gunshi_qc: PASS` または `gunshi_qc: PASS(WN)` の明記。未記載 = 却下 |
| QCレポート参照 | 軍師のレビュー報告のmsg_idまたはレポートファイルパス |

家老が将軍に完了報告する際のフォーマット:
```
subtask_XXX完了。[修正内容]。軍師QC PASS (Critical 0, Warning N)。
QCレポート: msg_XXXXXXXX / queue/reports/gunshi_report.yaml
```

**QC証跡なしの完了報告 = 未完了扱い。将軍は差し戻す。**

## 禁止事項

- 家老が軍師paneを経由せずAgent Toolの御意見番でQCレビューを実施すること
- 軍師paneが稼働中にもかかわらずfallbackを使用すること
- 家老が足軽の報告YAMLだけ読んで完了扱いにすること（ファイル本体未確認での完了判定禁止）
- 軍師QC完了前に将軍へ完了報告すること

## 違反時の措置

- 殿の逆鱗に触れる
- QCレビュー結果は無効とされ、やり直しとなる
- QC未依頼での完了報告は将軍が即却下し、家老の怠慢として記録する

## 背景（cmd_593事故）

subtask_593aにおいて、家老が軍師QCを依頼せず報告YAMLだけ読んで完了扱いにした。
その結果、start.shがgunicornを使っているのにpyproject.tomlにgunicornが未記載という
初歩的欠陥が素通りし、殿がclone時にエラーを踏んだ。

## 参照

- 軍師の役割: `instructions/gunshi.md`
- Report Flow: `CLAUDE.md` → Report Flow セクション
- 奉行チーム: `skills/bugyo-workflow.md`
- 必須レビュー観点: `skills/bakuhu/core/review-perspectives.md`
