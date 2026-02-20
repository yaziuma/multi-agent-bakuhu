#!/bin/bash
# get_agent_role.sh - pane IDからロール取得
# Identity分離設計書v3 セクション3 準拠
#
# pane IDからconfig/pane_role_map.yamlを参照してroleを解決。
# @agent_idとcross-check（不一致時はWARNINGをstderrに出しつつマッピング側を信頼）。
#
# 引数: pane ID（省略時は自動取得）
# stdout: role名 (shogun, karo, ashigaru, denrei)
# exit 0: 成功, exit 1: エラー, exit 2: fail-closed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAP_FILE="$PROJECT_DIR/config/pane_role_map.yaml"
MAP_HASH_FILE="$MAP_FILE.sha256"
MAP_LOCK_FILE="$MAP_FILE.lock"

# pane ID取得（引数 or 自動）
PANE_ID="${1:-}"
if [[ -z "$PANE_ID" ]]; then
    PANE_ID=$("$SCRIPT_DIR/get_pane_id.sh") || exit $?
fi

# マッピングファイル存在チェック
if [[ ! -f "$MAP_FILE" ]]; then
    echo "[ERROR] get_agent_role: pane_role_map.yaml not found" >&2
    exit 2
fi

# sha256整合性チェック
if [[ -f "$MAP_HASH_FILE" ]]; then
    if ! sha256sum -c "$MAP_HASH_FILE" --status 2>/dev/null; then
        echo "[ERROR] get_agent_role: pane_role_map.yaml integrity check failed — fail-closed" >&2
        exit 2
    fi
fi

# 共有ロックでマッピング読み取り
ROLE=""
exec 200>"$MAP_LOCK_FILE"
flock -s 200

# YAMLからpane IDに対応するroleを検索
# 形式: "  %N: role_name" or "%N: role_name"
ROLE=$(grep -E "^[[:space:]]*\"?${PANE_ID}\"?:" "$MAP_FILE" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d ' "' || true)

exec 200>&-

if [[ -z "$ROLE" ]]; then
    echo "[ERROR] get_agent_role: pane $PANE_ID not found in map" >&2
    exit 2
fi

# @agent_id cross-check（利用可能な場合のみ、権限判定の根拠としない）
if [[ -n "${TMUX_PANE:-}" ]]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")
    if [[ -n "$AGENT_ID" ]]; then
        # ashigaru1 → ashigaru にnormalize（roleはベースロール）
        AGENT_BASE_ROLE=$(echo "$AGENT_ID" | sed 's/[0-9]*$//')
        if [[ "$AGENT_BASE_ROLE" != "$ROLE" && "$AGENT_ID" != "$ROLE" ]]; then
            echo "[WARNING] get_agent_role: @agent_id='$AGENT_ID' != map_role='$ROLE' — trusting map" >&2
        fi
    fi
fi

echo "$ROLE"
exit 0
