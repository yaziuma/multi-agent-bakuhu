#!/bin/bash
# shogun_karo_status.sh — 家老の状態確認（コマンド送信前に使用）
# Usage: bash scripts/shogun_karo_status.sh
tmux capture-pane -t multiagent:0.0 -p | tail -20
