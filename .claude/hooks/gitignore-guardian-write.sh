#!/bin/bash
# gitignore-guardian-write.sh - .gitignore/.gitattributes への Write/Edit をブロック
# Pre-tool hook for Write and Edit tools
# Usage: Called by Claude Code before executing Write or Edit tool

set -euo pipefail

# stdinからJSON読み込みを試みる
FILE_PATH=""
if [[ ! -t 0 ]]; then
    # stdinが利用可能な場合、JSONから file_path フィールドを抽出
    JSON_INPUT=$(cat)
    if [[ -n "$JSON_INPUT" ]]; then
        # jq が利用可能な場合
        if command -v jq &> /dev/null; then
            FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null || echo "")
        fi
    fi
fi

# file_pathが取得できない場合は通す（hookの対象外）
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# .gitignore または .gitattributes で終わる場合はブロック
if [[ "$FILE_PATH" == *".gitignore" ]] || [[ "$FILE_PATH" == *".gitattributes" ]]; then
    echo "🛡️ .gitignore/.gitattributes の変更は殿の承認が必要です。" >&2
    echo "対象ファイル: $FILE_PATH" >&2
    echo "変更が必要な場合は、殿に許可を求めてください。" >&2
    exit 2
fi

# それ以外は許可
exit 0
