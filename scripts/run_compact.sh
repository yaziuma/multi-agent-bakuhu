#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# run_compact.sh — エージェントの/compactを外部実行
# Usage: bash scripts/run_compact.sh <agent_id>
# Example: bash scripts/run_compact.sh karo
#
# 設計:
#   1. agent_idからtmux paneを動的に解決
#   2. /compactコマンドを送信（send-keys 2回分離）
#   3. 完了を待機（"Compacted" 文字列をcapture-paneで監視）
#   4. check_context.shを呼んで圧縮後の%を表示
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Source common library ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/resolve_pane.sh"

# ─── Main ───
AGENT_ID="${1:-}"
TIMEOUT=60  # Minimum timeout for /compact (can take time)

if [ -z "$AGENT_ID" ]; then
    echo "Usage: bash scripts/run_compact.sh <agent_id>" >&2
    echo "Example: bash scripts/run_compact.sh karo" >&2
    exit 1
fi

# Resolve pane from agent_id
PANE_ID=$(resolve_pane "$AGENT_ID")
if [ -z "$PANE_ID" ]; then
    echo "ERROR: Cannot find pane for agent '$AGENT_ID'" >&2
    exit 1
fi

echo "Compacting $AGENT_ID..." >&2

# Send /compact command (text and Enter separated, per CLAUDE.md protocol)
if ! timeout 5 tmux send-keys -t "$PANE_ID" '/compact' 2>/dev/null; then
    echo "ERROR: Failed to send /compact command to agent '$AGENT_ID'" >&2
    exit 1
fi
sleep 0.3

if ! timeout 5 tmux send-keys -t "$PANE_ID" Enter 2>/dev/null; then
    echo "ERROR: Failed to send Enter to agent '$AGENT_ID'" >&2
    exit 1
fi

# Wait for compact to complete (look for "Compacted" message in pane output)
ELAPSED=0
COMPLETED=false
while [ $ELAPSED -lt $TIMEOUT ]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))

    # Capture recent output from pane
    OUTPUT=$(timeout 5 tmux capture-pane -t "$PANE_ID" -p -S -80 2>/dev/null || true)

    # Check for completion indicators
    if echo "$OUTPUT" | grep -iq "compacted"; then
        COMPLETED=true
        break
    fi
done

if [ "$COMPLETED" = false ]; then
    echo "ERROR: /compact did not complete within ${TIMEOUT}s for agent '$AGENT_ID'" >&2
    exit 1
fi

echo "done." >&2

# Wait for agent to finish processing compact result before sending /context
# After compact, agent displays summary which takes several seconds
sleep 10

# Get context percentage after compaction
CONTEXT_PERCENT=$(bash "${SCRIPT_DIR}/check_context.sh" "$AGENT_ID" 2>/dev/null || echo "unknown")

echo "Context: $CONTEXT_PERCENT"
