#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# yaml_archive_watcher.sh — done済みcmd自動退避監視スクリプト
# Usage: bash scripts/yaml_archive_watcher.sh
#
# 設計思想:
#   queue/shogun_to_karo.yaml の変更を inotifywait で監視
#   変更検知 → scripts/yaml_archive_done.sh を自動実行
#   done対象がなければスクリプトは何もせず終了（コスト無し）
#   バックグラウンドデーモンとして常駐
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# スクリプトのベースディレクトリ
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASEDIR"

# 対象ファイル・ログ・PIDファイル
TARGET="$BASEDIR/queue/shogun_to_karo.yaml"
LOGFILE="$BASEDIR/logs/yaml_archive_watcher.log"
PIDFILE="$BASEDIR/logs/yaml_archive_watcher.pid"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# PID check (多重起動防止)
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[ERROR] yaml_archive_watcher is already running (PID $OLD_PID)" >&2
        exit 1
    else
        # Stale PID file — clean up
        rm -f "$PIDFILE"
    fi
fi

# PID 登録
echo $$ > "$PIDFILE"
trap "rm -f $PIDFILE" EXIT

# inotifywait 確認
if ! command -v inotifywait &>/dev/null; then
    echo "[ERROR] inotifywait not found. Install: sudo apt install inotify-tools" >&2
    exit 1
fi

# ログディレクトリ確保
mkdir -p "$(dirname "$LOGFILE")"

log "yaml_archive_watcher started (PID $$)"

# メインループ
while true; do
    # CLOSE_WRITE イベントを待つ（ファイルが書き込まれて閉じられたとき）
    inotifywait -q -e close_write "$TARGET" 2>/dev/null

    # debounce: 短時間の連続変更をまとめる
    sleep 1

    # yaml_archive_done.sh を実行
    output=$(bash "$BASEDIR/scripts/yaml_archive_done.sh" 2>&1 || true)

    # 退避対象が0件ならログスキップ（ノイズ削減）
    if echo "$output" | grep -q "archived: 0"; then
        : # nothing to archive — skip logging
    else
        log "$output"
    fi
done
