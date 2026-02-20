#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# run_clear.sh — エージェントの/clearを外部実行
# Usage: bash scripts/run_clear.sh <agent_id>
# Example: bash scripts/run_clear.sh ashigaru1
#
# 設計:
#   1. agent_idからtmux paneを動的に解決
#   2. /clearコマンドを送信（send-keys 2回分離）
#   3. 完了確認（プロンプト "❯" が表示されるまで待機）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ─── Source common library ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/resolve_pane.sh"

# ─── Main ───
AGENT_ID="${1:-}"
TIMEOUT=10  # Timeout for /clear (should be quick)

if [ -z "$AGENT_ID" ]; then
    echo "Usage: bash scripts/run_clear.sh <agent_id>" >&2
    echo "Example: bash scripts/run_clear.sh ashigaru1" >&2
    exit 1
fi

# Resolve pane from agent_id
PANE_ID=$(resolve_pane "$AGENT_ID")
if [ -z "$PANE_ID" ]; then
    echo "ERROR: Cannot find pane for agent '$AGENT_ID'" >&2
    exit 1
fi

echo "Clearing $AGENT_ID..." >&2

# Send /clear command (text and Enter separated, per CLAUDE.md protocol)
if ! timeout 5 tmux send-keys -t "$PANE_ID" '/clear' 2>/dev/null; then
    echo "ERROR: Failed to send /clear command to agent '$AGENT_ID'" >&2
    exit 1
fi
sleep 0.3

if ! timeout 5 tmux send-keys -t "$PANE_ID" Enter 2>/dev/null; then
    echo "ERROR: Failed to send Enter to agent '$AGENT_ID'" >&2
    exit 1
fi

# Wait for clear to complete (look for prompt "❯" in pane output)
ELAPSED=0
COMPLETED=false
while [ $ELAPSED -lt $TIMEOUT ]; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))

    # Capture recent output from pane
    OUTPUT=$(timeout 5 tmux capture-pane -t "$PANE_ID" -p -S -10 2>/dev/null || true)

    # Check for prompt indicator (cleared session shows prompt)
    if echo "$OUTPUT" | grep -q "❯"; then
        COMPLETED=true
        break
    fi
done

if [ "$COMPLETED" = false ]; then
    echo "WARNING: /clear completion could not be verified within ${TIMEOUT}s for agent '$AGENT_ID'" >&2
fi

echo "Cleared $AGENT_ID."
