#!/bin/bash
# kill_playwright.sh - playwright-mcp専用プロセスkillスクリプト
# cmd_515: 殿の許可により作成
# 対象: playwright-mcpプロセスおよび関連Chromeプロセスのみ
# 汎用killではない。playwright関連以外のプロセスは一切触らない。

set -euo pipefail

# --- 色定義 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- dry-run モード（デフォルト） ---
DRY_RUN=true
if [[ "${1:-}" == "--force" ]]; then
    DRY_RUN=false
fi

echo "=== playwright-mcp プロセス一覧 ==="
echo ""

# --- playwright-mcp Node プロセス検出 ---
PLAYWRIGHT_PIDS=$(pgrep -f "playwright-mcp" 2>/dev/null || true)

if [[ -z "$PLAYWRIGHT_PIDS" ]]; then
    echo -e "${GREEN}playwright-mcp プロセスなし。killは不要。${NC}"
    exit 0
fi

echo -e "${YELLOW}検出されたplaywright-mcpプロセス:${NC}"
echo ""
for pid in $PLAYWRIGHT_PIDS; do
    if ps -p "$pid" -o pid,ppid,comm,args --no-headers 2>/dev/null; then
        true
    fi
done

echo ""

# --- mcp-chrome プロセス検出 ---
CHROME_PIDS=$(pgrep -f "mcp-chrome" 2>/dev/null || true)

if [[ -n "$CHROME_PIDS" ]]; then
    echo -e "${YELLOW}検出されたmcp-chrome関連プロセス:${NC}"
    echo ""
    for pid in $CHROME_PIDS; do
        if ps -p "$pid" -o pid,ppid,comm,args=COMMAND --no-headers 2>/dev/null | cut -c1-120; then
            true
        fi
    done
    echo ""
fi

# --- 合計 ---
ALL_PIDS="$PLAYWRIGHT_PIDS"
if [[ -n "$CHROME_PIDS" ]]; then
    ALL_PIDS="$ALL_PIDS $CHROME_PIDS"
fi
TOTAL=$(echo "$ALL_PIDS" | wc -w)

echo -e "合計: ${YELLOW}${TOTAL}${NC} プロセス"
echo ""

# --- dry-run / force ---
if $DRY_RUN; then
    echo -e "${YELLOW}[dry-run] killは実行しません。実行するには:${NC}"
    echo "  bash scripts/kill_playwright.sh --force"
    exit 0
fi

echo -e "${RED}playwright-mcp関連プロセスをkillします...${NC}"

# playwright-mcpを先にkill（Chromeは子プロセスとして自動終了する場合あり）
for pid in $PLAYWRIGHT_PIDS; do
    if kill "$pid" 2>/dev/null; then
        echo -e "  ${GREEN}killed${NC} PID $pid (playwright-mcp)"
    else
        echo -e "  ${RED}failed${NC} PID $pid"
    fi
done

# 少し待ってからChrome残存を確認・kill
sleep 1
REMAINING_CHROME=$(pgrep -f "mcp-chrome" 2>/dev/null || true)
if [[ -n "$REMAINING_CHROME" ]]; then
    echo "Chrome残存プロセスをkillします..."
    for pid in $REMAINING_CHROME; do
        if kill "$pid" 2>/dev/null; then
            echo -e "  ${GREEN}killed${NC} PID $pid (mcp-chrome)"
        else
            echo -e "  ${RED}failed${NC} PID $pid"
        fi
    done
fi

# --- ロックファイル除去 ---
LOCK_DIR="$HOME/.cache/ms-playwright/mcp-chrome-fe46603"
if [[ -d "$LOCK_DIR/SingletonLock" ]] || [[ -f "$LOCK_DIR/SingletonLock" ]]; then
    rm -f "$LOCK_DIR/SingletonLock" 2>/dev/null && echo -e "${GREEN}SingletonLock除去完了${NC}"
fi

echo ""
echo -e "${GREEN}完了。ブラウザが解放されました。${NC}"
