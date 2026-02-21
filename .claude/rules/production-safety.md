# Production Safety Rules (Lord's absolute order - all agents)

## 1. .gitignore / .gitattributes Protection Rule

**.gitignore and .gitattributes are protected files. NO agent may modify them without explicit Lord permission.**

- Read (cat, grep, git diff, etc.) is permitted
- Write, Edit, sed, echo redirect, cp, mv, and ALL other modification operations are **FORBIDDEN**
- `git add .gitignore`, `git add .`, `git add -A` are **FORBIDDEN** (may include .gitignore changes)
- `git add -f` / `git add --force` are **FORBIDDEN**
- Guardian hooks (`.claude/hooks/gitignore-guardian-*.sh`) enforce this automatically
- To modify .gitignore: request Lord's approval → Lord or Shogun executes directly
- Violations will be immediately reverted

## 2. Mandatory Review Rule

**ALL ashigaru work products MUST be reviewed before marking as done.**

- No task may be marked `status: done` without review
- Reviewer: goikenban (preferred) or karo (acceptable)
- Review scope: correctness, completeness, security, acceptance criteria met
- If review finds Critical issues: fix and re-review before done
- If review finds only Warning/Suggestion: karo's judgment whether to fix or accept
- Karo must verify review was conducted before updating dashboard with completion
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
