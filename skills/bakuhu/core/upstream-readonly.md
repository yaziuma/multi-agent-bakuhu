# Upstream由来ファイル 読み取り専用ルール（エージェント向けガイド）

## 絶対ルール

**upstream由来ファイルへのWrite/Edit操作は禁止。読み取りのみ許可。**

詳細ルールは `.claude/rules/bakuhu/upstream-integrity.md` を参照。

## upstream由来ファイル一覧（編集禁止対象）

以下のファイル・ディレクトリは upstream（yohey-w/multi-agent-shogun）由来である。

| パス | 区分 |
|------|------|
| `instructions/*.md` | upstream由来 |
| `CLAUDE.md` | upstream由来 |
| `skills/*.md`（ルートレベル） | upstream由来 |
| `skills/bakuhu/core/*.md` | upstream由来（bakuhu統合スキル） |
| `skills/shogun-agent-status/` | upstream由来スキルディレクトリ |
| `skills/shogun-bloom-config/` | upstream由来スキルディレクトリ |
| `skills/shogun-model-list/` | upstream由来スキルディレクトリ |
| `skills/shogun-model-switch/` | upstream由来スキルディレクトリ |
| `skills/shogun-readme-sync/` | upstream由来スキルディレクトリ |
| `skills/shogun-screenshot/` | upstream由来スキルディレクトリ |
| `skills/skill-creator/` | upstream由来スキルディレクトリ |
| `instructions/generated/` | upstream由来（存在する場合） |
| `templates/*.md` | upstream由来 |

## 禁止操作

| 禁止行為 | 理由 |
|----------|------|
| Write/Edit ツールで上記ファイルを変更 | upstream整合性が壊れる |
| bakuhu固有ルール・設定を上記ファイルに追記 | upstream mergeでコンフリクトが発生する |
| `git mv` で上記ファイルを移動 | upstream整合性が壊れる |
| `sed`, `awk`, `echo >` 等でshell経由変更 | Write/Editと同様に禁止 |

## 許可される操作

| 操作 | 用途 |
|------|------|
| Read（cat, head, tail 等） | 内容確認・参照 |
| Grep（grep, rg 等） | 内容検索 |
| upstream mergeによる更新 | merge時のみ（upstream由来の変更を取り込む） |

## bakuhu固有ルールの配置先

upstream由来ファイルに書きたい内容は、必ず以下に配置すること:

| 配置先 | 用途 |
|--------|------|
| `.claude/rules/bakuhu/*.md` | 幕府固有の全ルール |
| `.claude/rules/dev/*.md` | 開発環境固有ルール |

## 違反時の対応

1. 違反したファイルは即時 `git revert` される
2. 違反者は家老に報告され、記録される
3. 繰り返し違反は処分対象となる

## 参照

- 詳細ルール: `.claude/rules/bakuhu/upstream-integrity.md`
- 配置ルール: `.claude/rules/bakuhu/settings-placement-rule.md`
