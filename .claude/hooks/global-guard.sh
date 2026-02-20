#!/bin/bash
# global-guard.sh - 全体共通ガード
# Identity分離設計書v3 セクション7 準拠（忍び#7反映）
# 全ロール共通のセキュリティポリシー。最終防衛ライン。
# 役職に依存しない汎用的なセキュリティポリシーを適用。

set -euo pipefail

HOOK_NAME="global-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# NOTE: global-guardはロールチェック不要（全ロールで実行）
# ただしtmux外の場合はスキップ（hook_common.shのget_role()はtmux必須のため
# global guardは独自にtmux判定する）

# stdinからコマンド取得
COMMAND=$(read_command_from_stdin)

# コマンドが空の場合は通す
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# === 破壊的操作の絶対禁止（CLAUDE.md Tier 1 準拠） ===

# D001: rm -rf / , /home/, /mnt/, ~
if [[ "$COMMAND" =~ rm[[:space:]]+-rf[[:space:]]+/ ]] && [[ ! "$COMMAND" =~ rm[[:space:]]+-rf[[:space:]]+/[^[:space:]]+ ]]; then
    hook_log "$HOOK_NAME" "GLOBAL_DENY_RM_RF_ROOT" "command=$COMMAND" "deny"
    echo "D001: ルートディレクトリの削除は絶対禁止です。" >&2
    exit 2
fi

if [[ "$COMMAND" =~ rm[[:space:]].*-rf?[[:space:]]+(~|/home/[^[:space:]]*$|/mnt/[^[:space:]]*$) ]]; then
    # /home/* や /mnt/* 直下の広範囲削除をチェック
    if [[ "$COMMAND" =~ rm[[:space:]].*(-rf|-r[[:space:]]+-f|-f[[:space:]]+-r)[[:space:]]+(~|/home/\*|/mnt/\*|/mnt/c/\*|/mnt/d/\*) ]]; then
        hook_log "$HOOK_NAME" "GLOBAL_DENY_RM_WIDE" "command=$COMMAND" "deny"
        echo "D001: ホーム/マウントディレクトリの広範囲削除は禁止です。" >&2
        exit 2
    fi
fi

# D003: git push --force (--force-with-lease以外)
if [[ "$COMMAND" =~ git[[:space:]]+push[[:space:]] ]]; then
    if [[ "$COMMAND" =~ --force($|[[:space:]]) ]] || [[ "$COMMAND" =~ -f($|[[:space:]]) ]]; then
        if [[ ! "$COMMAND" =~ --force-with-lease ]]; then
            hook_log "$HOOK_NAME" "GLOBAL_DENY_GIT_PUSH_FORCE" "command=$COMMAND" "deny"
            echo "D003: git push --force は禁止です。--force-with-lease を使用してください。" >&2
            exit 2
        fi
    fi
fi

# D004: git reset --hard
if [[ "$COMMAND" =~ git[[:space:]]+reset[[:space:]]+--hard ]]; then
    hook_log "$HOOK_NAME" "GLOBAL_DENY_GIT_RESET_HARD" "command=$COMMAND" "deny"
    echo "D004: git reset --hard は禁止です。git stash を使用してください。" >&2
    exit 2
fi

# D004: git clean -f
if [[ "$COMMAND" =~ git[[:space:]]+clean[[:space:]]+-f ]]; then
    hook_log "$HOOK_NAME" "GLOBAL_DENY_GIT_CLEAN_F" "command=$COMMAND" "deny"
    echo "D004: git clean -f は禁止です。git clean -n (dry run) を先に実行してください。" >&2
    exit 2
fi

# D005: sudo
if [[ "$COMMAND" =~ ^sudo[[:space:]] ]]; then
    hook_log "$HOOK_NAME" "GLOBAL_DENY_SUDO" "command=$COMMAND" "deny"
    echo "D005: sudo は禁止です。" >&2
    exit 2
fi

# D006: tmux kill-server / kill-session
if [[ "$COMMAND" =~ tmux[[:space:]]+kill-(server|session) ]]; then
    hook_log "$HOOK_NAME" "GLOBAL_DENY_TMUX_KILL" "command=$COMMAND" "deny"
    echo "D006: tmux kill-server/kill-session は禁止です。" >&2
    exit 2
fi

# D008: pipe-to-shell
if [[ "$COMMAND" =~ (curl|wget)[[:space:]].*\|[[:space:]]*(bash|sh) ]]; then
    hook_log "$HOOK_NAME" "GLOBAL_DENY_PIPE_TO_SHELL" "command=$COMMAND" "deny"
    echo "D008: pipe-to-shell パターンは禁止です。" >&2
    exit 2
fi

# デフォルト許可（global guardは最終防衛ラインのみ）
exit 0
