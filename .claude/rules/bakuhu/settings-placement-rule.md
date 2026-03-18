# Claude Code Settings File Placement Rule (Lord's absolute order)

<!-- bakuhu-specific: Claude Code設定ファイルの配置ルール -->

## 原則

**hooks, rules, commands, etc. must be in project-level `.claude/`, NOT global.**

## 配置ルール

| 配置先 | 許可 | 理由 |
|--------|------|------|
| `{project}/.claude/hooks/` | ✅ 必須 | プロジェクト固有 |
| `{project}/.claude/rules/` | ✅ 必須 | プロジェクト固有 |
| `{project}/.claude/settings.json` | ✅ 必須 | プロジェクト固有 |
| `~/.claude/hooks/` | ❌ 禁止 | 全プロジェクトに影響、エラーの原因 |
| `~/.claude/rules/` | ❌ 禁止 | 全プロジェクトに影響、エラーの原因 |

## 禁止されている操作

- `~/.claude/hooks/` にhookファイルを作成すること
- `~/.claude/rules/` にルールファイルを作成すること
- グローバルな `~/.claude/settings.json` にプロジェクト固有設定を記述すること

## 理由

グローバル配置は他のプロジェクトにも影響を与え、意図しないエラーを引き起こす。
各設定はプロジェクトのコンテキスト内に閉じていなければならない。

**Violation = Lord's wrath. Obey absolutely.**
**違反 = 殿の逆鱗に触れる。絶対に遵守せよ。**

## 参照

- hookの実装例: `.claude/hooks/` 内の既存ファイル
- 本番変更手順: `.claude/rules/bakuhu/production-safety.md`
