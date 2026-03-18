# Git Commit Rule (Lord's absolute order - all agents)

<!-- bakuhu-specific: 殿の許可なしコミット禁止ルール -->

## 原則

**Commits require explicit Lord permission. No repository commits without it.**

## 手順

1. 殿の承認を得る
2. 将軍が殿に確認 → 許可を家老経由で足軽に中継
3. 足軽がコミット実行

## 重要な区別

| 記述 | 意味 |
|------|------|
| task YAML の "Commit" | 家老の指示であり、**殿の許可ではない** |
| 殿の許可 | 将軍が殿に直接確認し、明示的に得た承認 |

task YAMLに「コミットせよ」と書いてあっても、それだけでは不十分。
**殿の許可が別途必要。**

## 違反時の措置

- 違反コミットは即リバートされる
- 繰り返し違反者は処分される

## 参照

- 本番環境変更手順: `.claude/rules/bakuhu/production-safety.md`
- 指揮系統: `CLAUDE.md` → Shogun Mandatory Rules
