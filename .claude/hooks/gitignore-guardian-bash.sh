#!/bin/bash
# gitignore-guardian-bash.sh v2 - Protected file complete guard
# Pre-tool hook for Bash tool
# ALLOWLIST approach: only known-safe read-only commands permitted.
# All other commands involving protected files are BLOCKED by default.
# cmd_322r2 — allowlist rewrite (goikenban Critical fix)
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
   echo "$COMMAND" | grep -qP 'git\s+add\s+.*(--all\b|--update\b|-[a-zA-Z]*[Au])'; then
    echo "BLOCKED: git add . / git add -A / git add --all / git add -u is forbidden." >&2
    echo "Use individual file names (excluding protected files)." >&2
    exit 2
fi

# --- RULE 3: Protected file ALLOWLIST ---
# If command mentions .gitignore or .gitattributes, apply allowlist.
if [[ "$COMMAND" =~ \.gitignore|\.gitattributes ]]; then
    # 3a: Redirect TO protected files = immediate block
    # Only blocks when redirect target contains .gitignore/.gitattributes
    # e.g. "echo x > .gitignore" blocked, "cat .gitignore > /dev/null" allowed
    if echo "$COMMAND" | grep -qP '>>?\s*\S*\.git(ignore|attributes)'; then
        echo "BLOCKED: Redirect to protected files is forbidden." >&2
        exit 2
    fi

    # 3b: Split by pipe/chain, check each segment with protected filename
    BLOCK_REASON=""
    while IFS= read -r seg; do
        trimmed=$(echo "$seg" | sed 's/^[[:space:]]*//')
        [[ -z "$trimmed" ]] && continue

        # Only check segments mentioning protected files
        if ! echo "$seg" | grep -qE '\.(gitignore|gitattributes)'; then
            continue
        fi

        # Extract first command word
        first_cmd=$(echo "$trimmed" | awk '{print $1}')

        # Allowlist: safe read-only commands
        case "$first_cmd" in
            cat|head|tail|less|more|wc|file|stat|diff|grep|rg|ag|bat|ls|test|\[|readlink|realpath|basename|dirname|md5sum|sha256sum|hexdump|xxd|strings)
                continue ;;
        esac

        # Safe git subcommands (read-only only)
        # Skip flags (-C etc.), paths (/...), config values (key=val) to find actual subcommand
        if [[ "$first_cmd" == "git" ]]; then
            git_sub=$(echo "$trimmed" | sed 's/^git[[:space:]]*//' | awk '{
                for(i=1;i<=NF;i++){
                    if($i ~ /^-/) continue
                    if($i ~ /[\/=.]/) continue
                    print $i; exit
                }
            }')
            case "$git_sub" in
                diff|log|show|status|blame|ls-files)
                    continue ;;
            esac
        fi

        # bash -n (syntax check only)
        if [[ "$first_cmd" == "bash" ]] && echo "$trimmed" | grep -qP '^\s*bash\s+-n\b'; then
            continue
        fi

        # Not in allowlist = BLOCKED
        BLOCK_REASON="$first_cmd"
        break
    done < <(echo "$COMMAND" | sed 's/|/\n/g; s/&&/\n/g; s/;/\n/g')

    if [[ -n "$BLOCK_REASON" ]]; then
        echo "BLOCKED: '$BLOCK_REASON' is not allowed to operate on protected files." >&2
        echo "Only read-only commands (cat, grep, git diff, etc.) are permitted." >&2
        echo "Full command: $COMMAND" >&2
        exit 2
    fi

    # All segments passed allowlist
    exit 0
fi

# --- Commands not involving protected files pass through ---
exit 0
