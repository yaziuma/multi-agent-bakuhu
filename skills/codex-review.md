# Codexレビュー開発フロー（幕府版）

## 1. 目的

* **Claude Code（足軽）**を主に使って実装を進める
* PR作成後、GitHub上で **`@codex review` による一次レビュー**を必ず挟む
* 人間レビュー（殿）は **Codexレビューを踏まえて**行い、指摘の取りこぼしを減らす

幕府では、**御意見番（goikenban）によるローカルレビュー**と**目付（metsuke）によるUI実機検証**を追加して、多段階の品質チェック体制を構築する。

---

## 2. 対象リポジトリ

* **queue-viewer**（試験導入中）
* 今後、他のプロジェクトにも拡大予定

---

## 3. 幕府における開発フロー

### Step 1: 足軽実装（Claude Code）

* ローカルで足軽（Claude Code）を使って実装
* コミットを小さく刻む（後でレビューが読みやすい）

**推奨ルール**

* 1PR = 1目的（バグ修正/機能追加/リファクタを混ぜない）
* PRの差分を増やしすぎない（Codexも人間も精度が上がる）

---

### Step 2: 御意見番（goikenban）ローカルレビュー

* PR作成前に、**御意見番（goikenban）によるローカルレビュー**を実施
* 御意見番は幕府独自のコードレビュー役（Task tool Agent Team）
* セキュリティ、エッジケース、設計上の欠陥を厳しく指摘
* **コード修正権限なし**、レビュー専任

---

### Step 3: PR作成（Draft推奨）

* GitHubに push → PR作成
* まずは **Draft PR** にしておくのがおすすめ
  → CIや説明が整ってから Ready にする

**PR本文に必須情報**

* 変更の目的（なぜ必要か）
* 影響範囲（どこに影響するか）
* テスト方法（コマンド/手順）
* 注意点（互換性、設定変更、マイグレーション有無）

---

### Step 4: `@codex review` 実行（一次レビュー）

PRのコメント欄（Conversation）にこれを書く：

```
@codex review
```

これでCodexがGitHub上で標準のコードレビューとして返す。

#### 精度を上げる（推奨テンプレ）

用途に応じて、同じコメントに観点を足す：

**セキュリティ重視**

```
@codex review
Focus: security issues, authz/authn, input validation, secrets.
```

**パフォーマンス重視**

```
@codex review
Focus: performance regressions, unnecessary queries/IO, memory usage.
```

**FastAPI等でよく効くやつ**

```
@codex review
Focus:
- auth/authz
- input validation
- exception handling
- logging and PII leakage
- performance regressions
```

---

### Step 5: Codex指摘反映

* Codexの指摘を修正して追加コミット
* 修正したら、必要ならもう一回 `@codex review`

#### ⚠️ 注意（余計なタスク起動を避ける）

Codexが書いたレビューコメントへの返信で、うっかり `@codex` を含めると **意図せず新しいタスクが起動する**報告がある。
→ 返信に `@codex` を入れない / 必ず `@codex review` だけにする、が安全。

---

### Step 6: 目付（metsuke）UI実機検証（UI変更がある場合）

* **UI変更を伴うPRの場合のみ**、目付（metsuke）による実機検証を実施
* ブラウザでの動作確認、スクリーンショット撮影、視覚的な問題（CSSコントラスト等）の検出
* curlの200応答だけでは不十分。**実際に目で見る**ことが重要

---

### Step 7: 殿の最終承認（本レビュー）

* Codex指摘が取り込まれた状態で、殿（人間レビュー）が最終承認
* 重要箇所だけ重点的に見れる（一次フィルタ効果）

---

### Step 8: マージ

* CI通過
* 必要な承認数を満たす
* マージ

---

## 4. PRテンプレート（queue-viewer）

queue-viewerでは、`.github/pull_request_template.md` に以下を含める：

```md
## Codex review（必須）
- [ ] PRコメントで `@codex review` を実行した
- [ ] Codex指摘を反映した（または、反映しない理由を記載した）
```

これで「やった/やってない」がPR上で追跡できる。

---

## 5. Codexレビューのコツ

### 5.1 1PR = 1目的

バグ修正/機能追加/リファクタを混ぜない。差分が大きくなるとCodexの精度が下がる。

### 5.2 PR差分を小さく保つ

Codexも人間も読みやすくなる。レビュー精度が向上。

### 5.3 Focus指示でセキュリティ/パフォーマンス重点化可能

`@codex review` に続けて `Focus:` セクションを追加することで、特定の観点を重点的にレビューさせることができる。

### 5.4 コメント返信に@codexを入れない

Codexの指摘への返信で `@codex` を含めると、意図せず新しいタスクが起動する。必ず `@codex review` だけにする。

---

## 6. 役割分担（幕府版）

| 役割 | 担当 | 説明 |
|------|------|------|
| **実装** | 足軽（Claude Code） | 現場で建てる大工 |
| **ローカルレビュー** | 御意見番（goikenban） | 幕府独自、厳格なコードレビュー |
| **一次レビュー** | Codex review | 検査員（GitHub PR上） |
| **UI実機検証** | 目付（metsuke） | 幕府独自、ブラウザ実機確認 |
| **最終承認** | 殿（人間レビュー） | 施主/監督、最終検査 |

たとえると、

* **足軽（Claude Code）** = "現場で建てる大工"
* **御意見番（goikenban）** = "設計図面の厳密審査官"（幕府独自）
* **Codex review** = "検査員（一次検査）"
* **目付（metsuke）** = "完成品の実地検査"（幕府独自）
* **殿** = "施主/監督（最終検査）"

---

## 7. 前提条件

### 7.1 Codex側の準備

* Codex webでGitHubを接続して、対象リポジトリにアクセスできる状態にする（Codex CloudのGitHub連携）

### 7.2 GitHub側の推奨設定

* **ブランチ保護**で「PR必須」「レビュー必須」を有効化
  → `@codex review` を"手動オペ"でも確実に挟めるようにする

---

## 8. そのまま使える「PRコメント」テンプレ集

### 最小

```
@codex review
```

### 重点（FastAPIとかでよく効くやつ）

```
@codex review
Focus:
- auth/authz
- input validation
- exception handling
- logging and PII leakage
- performance regressions
```

### "差分だけ見ろ"運用

```
@codex review
Please review only the diff in this PR. Flag any behavior changes or breaking changes.
```

---

## まとめ（要点）

* **幕府フロー**: 足軽実装 → **御意見番** → PR作成 → `@codex review` → 指摘反映 → **目付**（UI変更時） → 殿の最終承認 → マージ
* PRテンプレにチェック欄を入れて、レビュー漏れを潰す
* Codexレビューコメントに返信する時、うっかり `@codex` を入れると意図せず再起動する可能性があるから注意
* 幕府独自の要素（御意見番、目付）と一般的なCodexフローを統合した多段階品質チェック体制

---

## 参考資料

殿の結論文書: `/home/quieter/projects/multi-agent-bakuhu/queue/殿/reports/Codexレビュー対応.md`

公式URL:
* [Use Codex in GitHub](https://developers.openai.com/codex/integrations/github/)
* [Introducing upgrades to Codex](https://openai.com/index/introducing-upgrades-to-codex/)
* [Build Code Review with the Codex SDK](https://developers.openai.com/cookbook/examples/codex/build_code_review_with_codex_sdk/)
* [Replies to Codex's PR code review comments triggers new ...](https://github.com/openai/codex/issues/11442)
