#!/bin/bash
# karo-guard.sh - 家老コマンドガード
# Identity分離設計書v3 セクション7 準拠
# 実装コマンド禁止、許可リスト優先、デフォルト許可

set -euo pipefail

HOOK_NAME="karo-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: karoロール以外は即exit 0
check_role_match "karo"

# stdinからコマンド取得
COMMAND=$(read_command_from_stdin)

# コマンドが空の場合は通す
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# ポリシーファイルパス
POLICY_FILE="$SCRIPT_DIR/policies/karo_policy.yaml"

# === 禁止リスト判定 ===
DENY_PATTERNS=(
    "python "
    "python3 "
    "pytest"
    "npm "
    "node "
    "ruff "
    "uvicorn"
    "docker "
)

for pattern in "${DENY_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        hook_log "$HOOK_NAME" "KARO_DENY" "command contains '$pattern'" "deny"
        echo "家老は実装コマンドを直接実行できません: $pattern" >&2
        echo "足軽に委譲してください。" >&2
        exit 2
    fi
done

# デフォルト許可
exit 0
