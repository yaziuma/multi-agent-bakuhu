#!/bin/bash
# gitignore-guardian-bash.sh v4 - Protected file write guard
# Pre-tool hook for Bash tool
# Blocks operations that ACTUALLY MODIFY .gitignore/.gitattributes.
# Does NOT block commands that merely mention these filenames (e.g., in message strings).
# cmd_322r2 — allowlist rewrite (goikenban Critical fix)
# v3 — RULE 3 rewrite: block write-ops only, not string mentions
# v4 — RULE 3b removed: git add .gitignore now allowed (殿の設計定義修正)
#      守るべきは「内容変更」のみ。git add は内容変更ではない。
set -euo pipefail

# --- Command extraction ---
COMMAND="${1:-}"
if [[ -z "$COMMAND" ]] && [[ ! -t 0 ]]; then
    JSON_INPUT=$(cat)
    if [[ -n "$JSON_INPUT" ]]; then
        if command -v jq &> /dev/null; then
            COMMAND=$(echo "$JSON_INPUT" | jq -r '.tool_input.command // .parameters.command // .command // empty' 2>/dev/null || echo "")
        fi
    fi
fi
if [[ -z "$COMMAND" ]]; then
    COMMAND="${BASH_COMMAND:-}"
fi
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# --- RULE 1: git add -f / --force always blocked ---
if [[ "$COMMAND" =~ git[[:space:]]+add[[:space:]].*(-f|--force) ]]; then
    echo "BLOCKED: git add -f/--force is forbidden." >&2
    exit 2
fi

# --- RULE 2: git add . / git add -A / git add --all / git add -u always blocked ---
# Part A: blocks "git add ." including variants: ./, .*, -- ., -v . etc.
# Part B: blocks --all, -A, -u, --update including combined flags (-Av, -vA, -uv etc.)
if echo "$COMMAND" | grep -qP 'git\s+add\s+(-[\w-]+\s+)*(--\s+)?\.\s*(/|\*|\s|&&|\||;|$)' || \
   echo "$COMMAND" | grep -qP 'git\s+add\s+(-[\w-]+\s+)*(-[a-zA-Z]*[Au]\b|--all\b|--update\b)'; then
    echo "BLOCKED: git add . / git add -A / git add --all / git add -u is forbidden." >&2
    echo "Use individual file names (excluding protected files)." >&2
    exit 2
fi

# --- RULE 3: Block only operations that ACTUALLY WRITE to protected files ---
# Protected files: .gitignore, .gitattributes
#
# BLOCKED patterns (actual file modification):
#   1. Redirect to protected file: `echo x > .gitignore`, `cat foo >> .gitattributes`
#   2. cp/mv overwriting protected file as destination: `cp backup .gitignore`, `mv tmp .gitattributes`
#
# ALLOWED patterns (read-only, git operations, or string mention only):
#   - cat .gitignore
#   - git diff .gitignore
#   - git add .gitignore  <- NOW ALLOWED (殿の設計定義: git add は内容変更ではない)
#   - git commit (含む .gitignore のコミット)
#   - bash scripts/inbox_write.sh karo "message mentioning .gitignore" type from
#   - grep pattern .gitignore
#   - Any command where .gitignore appears only inside a quoted string argument

# 3a: Redirect TO protected files
# e.g. "echo x > .gitignore" or "cat foo >> .gitattributes"
if echo "$COMMAND" | grep -qP '>>?\s*\S*\.git(ignore|attributes)\b'; then
    echo "BLOCKED: Redirect to protected files (.gitignore/.gitattributes) is forbidden." >&2
    exit 2
fi

# 3b: REMOVED (v4) — git add .gitignore was blocked here but殿の設計定義により許可に変更。
#     守るべきは「内容変更」のみ。git add は内容変更ではなくステージング操作。

# 3c: cp or mv with protected file as DESTINATION (trailing argument)
# Matches: cp backup .gitignore, mv tmp.txt .gitattributes
# Anchors to end-of-line/end-of-command to ensure it's the destination
if echo "$COMMAND" | grep -qP '^\s*(cp|mv)\s+\S.*\s\.git(ignore|attributes)\s*$'; then
    echo "BLOCKED: cp/mv to protected files (.gitignore/.gitattributes) is forbidden." >&2
    exit 2
fi

# --- Commands not matching write patterns pass through ---
exit 0
