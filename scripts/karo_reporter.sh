#!/bin/bash
# karo_reporter.sh - 報告処理専門エージェントのメインループ
#
# 機能:
#   - queue/reports/urgent/ と queue/reports/normal/ を監視
#   - 緊急報告は即時処理、通常報告はバックグラウンド処理
#   - dashboard.md を自動更新
#
# 使用方法:
#   ./scripts/karo_reporter.sh

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NORMAL_DIR="$PROJECT_DIR/queue/reports/normal"
URGENT_DIR="$PROJECT_DIR/queue/reports/urgent"
PROCESSED_DIR="$PROJECT_DIR/queue/reports/processed"
DASHBOARD="$PROJECT_DIR/dashboard.md"
EMERGENCY_FLAG="$PROJECT_DIR/queue/EMERGENCY.flag"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_urgent() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚨 URGENT: $*"
}

# ディレクトリ初期化
init_directories() {
    mkdir -p "$NORMAL_DIR" "$URGENT_DIR" "$PROCESSED_DIR"
    mkdir -p "$PROCESSED_DIR/$(date +%Y-%m-%d)"
}

# YAMLから値を取得（yq が無い場合は grep/sed で代用）
yaml_get() {
    local file="$1"
    local key="$2"

    if command -v yq &> /dev/null; then
        yq -r ".$key // \"\"" "$file" 2>/dev/null || echo ""
    else
        # シンプルなgrep/sed フォールバック
        grep -E "^[[:space:]]*$key:" "$file" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | tr -d '"' || echo ""
    fi
}

# 通常報告を処理
process_normal_report() {
    local report_file="$1"
    local filename=$(basename "$report_file")

    log "Processing normal report: $filename"

    # 報告内容を読み取り
    local reporter=$(yaml_get "$report_file" "report.reporter")
    local title=$(yaml_get "$report_file" "report.title")
    local summary=$(yaml_get "$report_file" "report.summary")

    # dashboard.md に追記（簡易版）
    {
        echo ""
        echo "### 📋 報告: $title"
        echo "- **報告者**: $reporter"
        echo "- **時刻**: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "- **概要**: $summary"
        echo ""
    } >> "$DASHBOARD.tmp"

    # 処理済みに移動
    mv "$report_file" "$PROCESSED_DIR/$(date +%Y-%m-%d)/"

    log "Normal report processed: $filename"
}

# 緊急報告を処理
process_urgent_report() {
    local report_file="$1"
    local filename=$(basename "$report_file")

    log_urgent "Processing urgent report: $filename"

    # 報告内容を読み取り
    local reporter=$(yaml_get "$report_file" "report.reporter")
    local priority=$(yaml_get "$report_file" "report.priority")
    local title=$(yaml_get "$report_file" "report.title")
    local summary=$(yaml_get "$report_file" "report.summary")
    local requires_human=$(yaml_get "$report_file" "report.requires_human")

    # tmux 通知
    if command -v tmux &> /dev/null; then
        tmux display-message "🚨 URGENT: $title ($reporter)"
    fi

    # dashboard.md の要対応セクションに追記
    # TODO: 既存の要対応セクションに挿入するロジックが必要
    log_urgent "Title: $title"
    log_urgent "Summary: $summary"

    # 人間の判断が必要な場合はフラグを立てる
    if [ "$requires_human" = "true" ]; then
        echo "$(date -Iseconds) $filename" > "$EMERGENCY_FLAG"
        log_urgent "EMERGENCY FLAG SET - Human attention required!"
    fi

    # 処理済みに移動
    mv "$report_file" "$PROCESSED_DIR/$(date +%Y-%m-%d)/"

    log_urgent "Urgent report processed: $filename"
}

# 既存の報告を処理（起動時）
process_existing_reports() {
    log "Checking for existing reports..."

    # 緊急報告を先に処理
    for report in "$URGENT_DIR"/*.yaml 2>/dev/null; do
        [ -f "$report" ] && process_urgent_report "$report"
    done

    # 通常報告を処理
    for report in "$NORMAL_DIR"/*.yaml 2>/dev/null; do
        [ -f "$report" ] && process_normal_report "$report" &
    done

    wait
}

# メインループ
main() {
    log "Karo-Reporter starting..."
    log "Watching: $URGENT_DIR and $NORMAL_DIR"

    init_directories
    process_existing_reports

    log "Entering watch loop..."

    while true; do
        # 緊急報告を優先的にチェック
        for report in "$URGENT_DIR"/*.yaml 2>/dev/null; do
            if [ -f "$report" ]; then
                process_urgent_report "$report"
            fi
        done

        # inotifywait で両ディレクトリを監視（10秒タイムアウト）
        # タイムアウトすると緊急報告を再チェック
        inotifywait -q -r -e create -e moved_to -t 10 \
            "$NORMAL_DIR" "$URGENT_DIR" 2>/dev/null | while read -r event_path event_type event_file; do

            full_path="${event_path}${event_file}"

            # YAML ファイルのみ処理
            if [[ "$event_file" == *.yaml ]]; then
                # 緊急か通常かで処理を分岐
                if [[ "$event_path" == *"/urgent/"* ]]; then
                    process_urgent_report "$full_path"
                else
                    # 通常報告はバックグラウンドで処理
                    process_normal_report "$full_path" &
                fi
            fi
        done || true  # タイムアウトは正常

    done
}

# シグナルハンドラ
cleanup() {
    log "Karo-Reporter shutting down..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# 実行
main
