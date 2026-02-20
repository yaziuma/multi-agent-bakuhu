#!/bin/bash
# denrei-guard.sh - 伝令コマンドガード
# Identity分離設計書v3 セクション7 準拠
# 実装コマンド禁止、gemini/codex許可、デフォルト許可

set -euo pipefail

HOOK_NAME="denrei-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: denreiロール以外は即exit 0
check_role_match "denrei"

# stdinからコマンド取得
COMMAND=$(read_command_from_stdin)

# コマンドが空の場合は通す
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# === 許可リスト（最優先） ===
ALLOW_PATTERNS=(
    "gemini"
    "codex"
    "inbox_write.sh"
    "tmux capture-pane"
    "tmux display-message"
)

for pattern in "${ALLOW_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        exit 0
    fi
done

# === 禁止リスト ===
DENY_PATTERNS=(
    "python "
    "python3 "
    "pytest"
    "npm "
    "node "
    "ruff "
    "uvicorn"
)

for pattern in "${DENY_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        hook_log "$HOOK_NAME" "DENREI_DENY" "command contains '$pattern'" "deny"
        echo "伝令は実装コマンドを直接実行できません: $pattern" >&2
        exit 2
    fi
done

# デフォルト許可
exit 0
