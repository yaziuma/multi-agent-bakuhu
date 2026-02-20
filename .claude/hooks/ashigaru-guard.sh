#!/bin/bash
# ashigaru-guard.sh - 足軽コマンドガード
# Identity分離設計書v3 セクション7 準拠
# 将軍直接連絡禁止のみ、デフォルト許可

set -euo pipefail

HOOK_NAME="ashigaru-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: ashigaruロール以外は即exit 0
check_role_match "ashigaru"

# stdinからコマンド取得
COMMAND=$(read_command_from_stdin)

# コマンドが空の場合は通す
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# === 禁止リスト ===

# 将軍への直接連絡禁止
if [[ "$COMMAND" =~ inbox_write\.sh[[:space:]]+shogun ]]; then
    hook_log "$HOOK_NAME" "ASHIGARU_DENY_SHOGUN_INBOX" "command attempts shogun inbox" "deny"
    echo "足軽は将軍に直接連絡できません。家老経由で報告してください。" >&2
    exit 2
fi

# デフォルト許可
exit 0
