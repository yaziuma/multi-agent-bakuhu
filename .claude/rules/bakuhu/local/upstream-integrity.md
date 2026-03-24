---
paths:
  - "instructions/**"
  - "skills/**"
  - "CLAUDE.md"
  - "templates/**"
---

# Upstream Integrity Rule (Lord's absolute order - all agents)

<!-- bakuhu-specific: upstream整合ファイルへの幕府固有ルール書き込み禁止 -->

## 原則

**upstream対象ファイルへの一切の追記・変更を禁止。内容がbakuhu固有か汎用かは問わない。**

upstream整合ファイル（instructions/、CLAUDE.md、skills/、templates/等）には何も書くな。
幕府固有・汎用問わず、追加したい内容は必ず `skills/bakuhu/` または `.claude/rules/bakuhu/` に配置せよ。

**理由**: upstream（yohey-w/multi-agent-shogun）からの取り込み時のコンフリクトを最小限にするため。
内容が汎用的であっても upstream 対象ファイルに書くとコンフリクトが発生する。

## upstream整合ファイル（書き込み禁止対象）

| パス | 理由 |
|------|------|
| `instructions/*.md` | upstream由来。幕府固有追記禁止 |
| `CLAUDE.md` | upstream由来。幕府固有追記禁止 |
| `skills/shogun-agent-status/` | upstream由来。幕府固有追記禁止 |
| `skills/shogun-bloom-config/` | upstream由来。幕府固有追記禁止 |
| `skills/shogun-model-list/` | upstream由来。幕府固有追記禁止 |
| `skills/shogun-model-switch/` | upstream由来。幕府固有追記禁止 |
| `skills/shogun-readme-sync/` | upstream由来。幕府固有追記禁止 |
| `skills/shogun-screenshot/` | upstream由来。幕府固有追記禁止 |
| `skills/skill-creator/` | upstream由来。幕府固有追記禁止 |
| `templates/*.md` | upstream由来。幕府固有追記禁止 |

## bakuhu固有ファイル（書き込み可）

| パス | 理由 |
|------|------|
| `skills/bakuhu/` | bakuhu固有スキル。追記・修正可 |
| `skills/generated/` | PJ由来生成スキル。追記・修正可 |

## 幕府固有ルールの配置先

| 配置先 | 用途 |
|--------|------|
| `.claude/rules/bakuhu/*.md` | 幕府固有の全ルール |
| `.claude/rules/dev/*.md` | 開発環境固有ルール |

## 理由

upstream（yohey-w/multi-agent-shogun）からの取り込み時のコンフリクトを最小限にするため。
内容がbakuhu固有か汎用かに関わらず、upstream対象ファイルへの追記は全て禁止。
「汎用的な内容だから書いてよい」は誤り。汎用的であっても `skills/bakuhu/` に書け。

## 違反時の措置

- 殿の逆鱗に触れる
- 違反箇所は即時削除される
