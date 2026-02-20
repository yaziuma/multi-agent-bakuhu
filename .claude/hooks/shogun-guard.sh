#!/bin/bash
# shogun-guard.sh - 将軍（Shogun）コマンドガード
# Identity分離設計書v3 セクション7 準拠（忍び#7反映）
# shogunロール専用に再定義。許可リスト→禁止リスト→デフォルト拒否。
# 旧来の汎用ガード機能はglobal-guard.shに移管済み。

set -euo pipefail

HOOK_NAME="shogun-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: shogunロール以外は即exit 0
check_role_match "shogun"

# stdinからコマンド取得
COMMAND=$(read_command_from_stdin)

# コマンドが空の場合は通す
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# ========================================
# Step 1: 許可リスト判定（最優先）
# ========================================

ALLOWED_PATTERNS=(
    "inbox_write.sh"
    "shogun_whoami.sh"
    "shogun_karo_status.sh"
    "run_compact.sh"
    "run_clear.sh"
    "tmux capture-pane"
    "tmux display-message"
    "tmux send-keys"
    "check_context.sh"
)

for pattern in "${ALLOWED_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        hook_log "$HOOK_NAME" "SHOGUN_ALLOW" "pattern=$pattern" "allow"
        exit 0
    fi
done

# curl特殊判定（localhost/127.0.0.1のみ許可）
if [[ "$COMMAND" == *"curl"* ]]; then
    if [[ "$COMMAND" == *"localhost"* ]] || [[ "$COMMAND" == *"127.0.0.1"* ]]; then
        hook_log "$HOOK_NAME" "SHOGUN_ALLOW_CURL_LOCAL" "localhost curl" "allow"
        exit 0
    fi
fi

# ========================================
# Step 2: 禁止リスト判定
# ========================================

FORBIDDEN_PATTERNS=(
    "uvicorn"
    "inbox_watcher"
    "python "
    "python3 "
    "pytest"
    "ruff "
    "npm "
    "node "
    "kill "
    "killall "
    "pkill "
    "restart.sh"
    "start.sh"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        hook_log "$HOOK_NAME" "SHOGUN_DENY" "pattern=$pattern" "deny"
        echo "将軍禁止操作検出: $pattern" >&2
        echo "将軍はインフラ操作を直接実行できません。" >&2
        echo "家老経由で足軽に委譲してください。" >&2
        exit 2
    fi
done

# curl の外部URL判定（localhost以外）
if [[ "$COMMAND" == *"curl"* ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_DENY_CURL_EXTERNAL" "external curl" "deny"
    echo "将軍は外部APIへの直接アクセスを実行できません。" >&2
    echo "家老経由で足軽に委譲してください。" >&2
    exit 2
fi

# ========================================
# Step 3: デフォルト拒否
# ========================================

COMMAND_PREVIEW=$(echo "$COMMAND" | head -c 50)
hook_log "$HOOK_NAME" "SHOGUN_DEFAULT_DENY" "command=$COMMAND_PREVIEW" "deny"
echo "将軍は許可リスト外のコマンドを実行できません: $COMMAND_PREVIEW" >&2
exit 2
