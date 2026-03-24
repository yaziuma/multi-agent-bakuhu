#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# resolve_pane.sh — tmux pane dynamic resolution library
# Usage: source scripts/lib/resolve_pane.sh
#
# Provides resolve_pane() function:
#   resolve_pane <agent_id> → outputs pane_id or returns 1
# ═══════════════════════════════════════════════════════════════

# ─── Dynamic pane resolution ───
# Resolve pane_id from @agent_id custom variable.
# Same logic as inbox_watcher.sh.
resolve_pane() {
    local target_agent="$1"
    local pane

    # Search in multiagent session
    for pane in $(tmux list-panes -s -t multiagent -F '#{pane_id}' 2>/dev/null || true); do
        local aid
        aid=$(tmux display-message -t "$pane" -p '#{@agent_id}' 2>/dev/null || true)
        if [ "$aid" = "$target_agent" ]; then
            echo "$pane"
            return 0
        fi
    done

    # Fallback: check shogun session if not found in multiagent
    for pane in $(tmux list-panes -s -t shogun -F '#{pane_id}' 2>/dev/null || true); do
        local aid
        aid=$(tmux display-message -t "$pane" -p '#{@agent_id}' 2>/dev/null || true)
        if [ "$aid" = "$target_agent" ]; then
            echo "$pane"
            return 0
        fi
    done

    return 1
}
