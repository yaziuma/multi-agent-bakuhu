#!/bin/bash
set -euo pipefail

# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs queue/inbox

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

agent_exists() {
    local agent="$1"
    # Check if agent pane exists by @agent_id (dynamic resolution)
    local pane
    for pane in $(tmux list-panes -a -F '#{pane_id}' 2>/dev/null); do
        local aid
        aid=$(tmux display-message -t "$pane" -p '#{@agent_id}' 2>/dev/null || true)
        if [ "$aid" = "$agent" ]; then
            return 0
        fi
    done
    return 1
}

start_watcher_if_missing() {
    local agent="$1"
    local log_file="$2"

    ensure_inbox_file "$agent"
    if ! agent_exists "$agent"; then
        return 0
    fi

    if pgrep -f "scripts/inbox_watcher.sh ${agent}" >/dev/null 2>&1; then
        return 0
    fi

    # Let inbox_watcher.sh resolve pane and cli dynamically
    nohup bash scripts/inbox_watcher.sh "$agent" >> "$log_file" 2>&1 &
}

while true; do
    start_watcher_if_missing "shogun" "logs/inbox_watcher_shogun.log"
    start_watcher_if_missing "karo" "logs/inbox_watcher_karo.log"
    start_watcher_if_missing "ashigaru1" "logs/inbox_watcher_ashigaru1.log"
    start_watcher_if_missing "ashigaru2" "logs/inbox_watcher_ashigaru2.log"
    start_watcher_if_missing "ashigaru3" "logs/inbox_watcher_ashigaru3.log"
    start_watcher_if_missing "denrei1" "logs/inbox_watcher_denrei1.log"
    start_watcher_if_missing "denrei2" "logs/inbox_watcher_denrei2.log"
    sleep 5
done
