#!/bin/bash
# gitignore-guardian-write.sh - .gitignore/.gitattributes への Write/Edit をブロック
# Pre-tool hook for Write and Edit tools
# Usage: Called by Claude Code before executing Write or Edit tool

set -euo pipefail

# FILE_PATH取得: 優先順位
# 1. CLAUDE_TOOL_INPUT env var (lint-on-save.py と同様のアプローチ)
# 2. stdin からJSON読み込み
# 3. 取得できない場合 → fail-open (exit 0)
FILE_PATH=""

# 1. CLAUDE_TOOL_INPUT env var を先にチェック
if [[ -n "${CLAUDE_TOOL_INPUT:-}" ]]; then
    if command -v jq &> /dev/null; then
        FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null || echo "")
    fi
fi

# 2. stdinからJSON読み込みを試みる（CLAUDE_TOOL_INPUTで取得できなかった場合）
if [[ -z "$FILE_PATH" ]] && [[ ! -t 0 ]]; then
    JSON_INPUT=$(cat)
    if [[ -n "$JSON_INPUT" ]]; then
        # jq が利用可能な場合
        if command -v jq &> /dev/null; then
            FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null || echo "")
        fi
    fi
fi

# 3. FILE_PATHが取得できない場合はfail-open（このhookの目的は.gitignore保護のみ）
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
