# Production Safety Rules (Lord's absolute order - all agents)

## 1. .gitignore / .gitattributes Protection Rule

**.gitignore and .gitattributes are protected files. NO agent may modify their content without explicit Lord permission.**

- Read (cat, grep, git diff, etc.) is permitted
- Write, Edit, sed, echo redirect, cp, mv, and ALL other content modification operations are **FORBIDDEN**
- `git add .`, `git add -A` are **FORBIDDEN** (may include .gitignore changes)
- `git add -f` / `git add --force` are **FORBIDDEN**
- `git add .gitignore` (staging already-modified .gitignore) is **ALLOWED** with Lord's explicit permission — guardian hook enforces this
- Guardian hooks (`.claude/hooks/gitignore-guardian-*.sh`) enforce this automatically
- To modify .gitignore content: request Lord's approval → Lord or Shogun executes directly
- Violations will be immediately reverted

## 1.5. .gitignore Whitelist-Only Rule (Lord's absolute order - all agents, all projects)

**全プロジェクトの.gitignoreは純粋ホワイトリスト方式のみ許可。ブラックリスト（除外パターン）は一切禁止。**

- 方式: `*`（全拒否）+ `!*/`（ディレクトリ走査許可）+ `!`（個別許可）のみ
- `.venv/`, `__pycache__/`, `*.pyc`, `*.log` 等のブラックリスト行は**絶対禁止**
- 許可しないもの = 自動で除外。ブラックリスト不要が正しい設計
- ホワイトリスト方式ならエージェントが勝手にファイルを追加しても追跡されない
- .gitignoreのレビュー時、ブラックリスト行が1行でもあれば即却下
- 違反は殿の逆鱗に触れる

## 2. Mandatory Review Rule

**ALL ashigaru work products MUST be reviewed before marking as done.**

- No task may be marked `status: done` without review
- Reviewer: 軍師pane（qc-routing.md参照）。軍師無応答時のみfallback可
- Review scope: correctness, completeness, security, acceptance criteria met, **依存整合性**
- If review finds Critical issues: fix and re-review before done
- If review finds only Warning/Suggestion: karo's judgment whether to fix or accept
- Karo must verify review was conducted before updating dashboard with completion
- **家老は足軽の報告YAMLだけで完了判定してはならない。軍師QC PASSを確認してから将軍に完了報告すること**
- **QC証跡（軍師のmsg_idまたはレポートパス）なしの完了報告は将軍が却下する**
- This rule applies to ALL tasks including urgent/critical ones — no exceptions

## 3. Production Environment Change Procedure

**NEVER directly modify running hooks, .gitignore, or critical config files in production.**

Required procedure for any production change:

1. **Staging**: Create new version in `queue/staging/` (NOT in production path)
2. **Syntax Check**: `bash -n` or equivalent validation on staging file
3. **Review**: goikenban review on staging file. Critical 0 required.
4. **Backup**: `cp production-file production-file.bak` before any change
5. **Deploy**: `cp staging-file production-file` (atomic copy replacement)
6. **Test**: Verify production behavior after deployment
7. **Rollback**: If test fails, immediately `cp production-file.bak production-file`

- Write/Edit tool to `queue/staging/` — Bash heredoc is FORBIDDEN (guardian self-block risk)
- Only after goikenban review passes (Critical 0) may deployment proceed
- Backup files (.bak) must be retained until all tests pass

## 4. Pre-Launch Checklist for Commands (Shogun mandatory)

Before issuing any cmd that modifies production systems, Shogun MUST verify:

- [ ] All steps documented: what happens at each step
- [ ] Hook interference check: will any hook block the operation?
- [ ] Side effect analysis: file operations (git rm vs --cached, etc.)
- [ ] Permission check: which agents have write access to target paths?
- [ ] No direct production modification: staging → test → deploy
- [ ] Rollback procedure: documented recovery plan if deployment fails

This checklist exists because cmd_320-322's chain of failures (3 iterations) was caused by insufficient pre-launch verification.
