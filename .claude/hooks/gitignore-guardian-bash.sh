#!/bin/bash
# gitignore-guardian-bash.sh - git add -f による .gitignore 無視を防止
set -euo pipefail
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
if [[ "$COMMAND" =~ git[[:space:]].*add[[:space:]].*(-f|--force) ]]; then
    echo "🛡️ git add -f は禁止です。.gitignoreで除外されたファイルの強制追加はできません。" >&2
    exit 2
fi
exit 0
