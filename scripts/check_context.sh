#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# check_context.sh — エージェントのコンテキスト使用率を取得
# Usage: bash scripts/check_context.sh <agent_id>
# Example: bash scripts/check_context.sh karo → 30%
#
# 設計:
#   1. agent_idからtmux paneを動的に解決
#   2. /contextコマンドを送信（send-keys 2回分離）
#   3. 出力をcapture-paneでキャプチャ
#   4. コンテキスト使用率（%）を抽出して標準出力
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Source common library ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/resolve_pane.sh"

# ─── Main ───
AGENT_ID="${1:-}"

if [ -z "$AGENT_ID" ]; then
    echo "Usage: bash scripts/check_context.sh <agent_id>" >&2
    echo "Example: bash scripts/check_context.sh karo" >&2
    exit 1
fi

# Resolve pane from agent_id
PANE_ID=$(resolve_pane "$AGENT_ID")
if [ -z "$PANE_ID" ]; then
    echo "ERROR: Cannot find pane for agent '$AGENT_ID'" >&2
    exit 1
fi

# Send /context command (text and Enter separated, per CLAUDE.md protocol)
if ! timeout 5 tmux send-keys -t "$PANE_ID" '/context' 2>/dev/null; then
    echo "ERROR: Failed to send /context command to agent '$AGENT_ID'" >&2
    exit 1
fi
sleep 0.3

if ! timeout 5 tmux send-keys -t "$PANE_ID" Enter 2>/dev/null; then
    echo "ERROR: Failed to send Enter to agent '$AGENT_ID'" >&2
    exit 1
fi

# Wait for /context output to complete (3 seconds)
sleep 3

# Capture pane output (full scrollback buffer, last 80 lines)
OUTPUT=$(timeout 5 tmux capture-pane -t "$PANE_ID" -p -S -80 2>/dev/null)

if [ -z "$OUTPUT" ]; then
    echo "ERROR: No output captured from agent '$AGENT_ID'" >&2
    exit 1
fi

# Extract percentage from output
# /context output format: "114k/200k tokens (57%)" or similar
# First try to find the tokens line with percentage
PERCENT=$(echo "$OUTPUT" | grep -oE '[0-9]+k/[0-9]+k tokens \([0-9]+%\)' | head -1)
if [ -n "$PERCENT" ]; then
    # Full format found, extract just the percentage
    PERCENT=$(echo "$PERCENT" | grep -oE '[0-9]+%')
else
    # Fallback: any standalone percentage
    PERCENT=$(echo "$OUTPUT" | grep -oE '[0-9]+%' | head -1)
fi

if [ -z "$PERCENT" ]; then
    echo "ERROR: Cannot parse context percentage from output" >&2
    echo "Output was:" >&2
    echo "$OUTPUT" >&2
    exit 1
fi

# Output the percentage to stdout
echo "$PERCENT"
