#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# restart_all_watchers.sh — 全inbox watcher再起動（cmd_244修正後）
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "[$(date)] Stopping all existing inbox watchers..."
pkill -f "scripts/inbox_watcher.sh" || echo "No existing watchers found"
sleep 2

echo "[$(date)] Verifying watchers are stopped..."
if pgrep -f "scripts/inbox_watcher.sh" >/dev/null; then
    echo "[ERROR] Some watchers are still running. Force kill..."
    pkill -9 -f "scripts/inbox_watcher.sh" || true
    sleep 1
fi

echo "[$(date)] Starting watchers with dynamic pane resolution..."

# Start watchers for active agents (no pane argument — dynamic resolution)
for agent in shogun karo ashigaru1 ashigaru2 ashigaru3 denrei1 denrei2; do
    log_file="logs/inbox_watcher_${agent}.log"
    echo "[$(date)] Starting watcher for $agent..."
    nohup bash scripts/inbox_watcher.sh "$agent" >> "$log_file" 2>&1 &
    sleep 0.5
done

sleep 2

echo "[$(date)] Verifying watchers are running..."
ps aux | grep "inbox_watcher.sh" | grep -v grep || echo "[WARN] No watchers detected"

echo ""
echo "=== Watcher Status ==="
for agent in shogun karo ashigaru1 ashigaru2 ashigaru3 denrei1 denrei2; do
    if pgrep -f "scripts/inbox_watcher.sh ${agent}" >/dev/null 2>&1; then
        pid=$(pgrep -f "scripts/inbox_watcher.sh ${agent}" | head -1)
        echo "✓ $agent (PID: $pid)"
    else
        echo "✗ $agent (NOT RUNNING)"
    fi
done

echo ""
echo "[$(date)] Restart complete. Check logs/ for details."
