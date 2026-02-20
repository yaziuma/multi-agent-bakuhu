#!/bin/bash
# get_pane_id.sh - tmux pane ID (#D) 取得
# Identity分離設計書v3 セクション1 準拠
#
# stdout: %N 形式のpane ID
# exit 0: 成功
# exit 1: tmux外（通常コンテキスト）
# exit 2: tmux外（hookコンテキスト — fail-closed）

set -euo pipefail

# tmux外判定
if [[ -z "${TMUX:-}" ]]; then
    if [[ "${HOOK_CONTEXT:-}" == "true" ]]; then
        echo "[ERROR] get_pane_id: not in tmux (hook context) — fail-closed" >&2
        exit 2
    fi
    echo "[ERROR] get_pane_id: not in tmux" >&2
    exit 1
fi

# TMUX_PANE変数からpane IDを取得
if [[ -z "${TMUX_PANE:-}" ]]; then
    if [[ "${HOOK_CONTEXT:-}" == "true" ]]; then
        echo "[ERROR] get_pane_id: TMUX_PANE not set (hook context) — fail-closed" >&2
        exit 2
    fi
    echo "[ERROR] get_pane_id: TMUX_PANE not set" >&2
    exit 1
fi

echo "$TMUX_PANE"
exit 0
