#!/bin/bash
# shogun-task-guard.sh - 将軍（Shogun）Task toolガード
# 将軍がAgent Team（Task tool）を直接spawnすることを防ぐhook
# 許可: claude-code-guide, statusline-setup のみ
# 禁止: bugyo, ashigaru, goikenban 等、その他全て

set -euo pipefail

HOOK_NAME="shogun-task-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: shogunロール以外は即exit 0
check_role_match "shogun"

# stdinからsubagent_type取得
SUBAGENT_TYPE=$(read_subagent_type_from_stdin)

# subagent_typeが空の場合は拒否（fail-closed原則）
if [[ -z "$SUBAGENT_TYPE" ]]; then
    hook_log "$HOOK_NAME" "TASK_DENY_EMPTY" "subagent_type=empty" "deny"
    echo "将軍はAgent Teamを直接spawn不可。subagent_typeが未指定です。" >&2
    exit 2
fi

# ========================================
# 許可リスト判定
# ========================================

ALLOWED_TYPES=(
    "claude-code-guide"
    "statusline-setup"
)

for allowed in "${ALLOWED_TYPES[@]}"; do
    if [[ "$SUBAGENT_TYPE" == "$allowed" ]]; then
        hook_log "$HOOK_NAME" "TASK_ALLOW" "subagent_type=$SUBAGENT_TYPE" "allow"
        exit 0
    fi
done

# ========================================
# 許可リスト外 → 拒否
# ========================================

hook_log "$HOOK_NAME" "TASK_DENY" "subagent_type=$SUBAGENT_TYPE" "deny"
echo "将軍はAgent Teamを直接spawn不可。家老経由で委譲せよ。" >&2
echo "要求されたsubagent_type: $SUBAGENT_TYPE" >&2
exit 2
