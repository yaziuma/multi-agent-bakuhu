#!/bin/bash
# shogun_whoami.sh — 将軍自己識別（セッション開始時に使用）
# Usage: bash scripts/shogun_whoami.sh
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
