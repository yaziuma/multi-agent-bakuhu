#!/bin/bash
# gemini_cached.sh - Gemini CLI のキャッシュ付きラッパー
#
# 使用方法:
#   ./scripts/gemini_cached.sh "クエリ内容" [出力ファイル]
#
# 機能:
#   - 同一クエリの結果をキャッシュ（24時間有効）
#   - 出力の完全性を検証
#   - エラーハンドリング
#
# 例:
#   ./scripts/gemini_cached.sh "Pythonのasyncioについて説明せよ"
#   ./scripts/gemini_cached.sh "調査内容" output.md

set -euo pipefail

# 設定
CACHE_DIR="${HOME}/.cache/gemini_cache"
CACHE_TTL_HOURS=24
MAX_RETRIES=3
RETRY_DELAY=5

# 引数チェック
if [ $# -lt 1 ]; then
    echo "Usage: $0 <query> [output_file]" >&2
    exit 1
fi

QUERY="$1"
OUTPUT_FILE="${2:-}"

# キャッシュディレクトリ作成
mkdir -p "$CACHE_DIR"

# クエリのハッシュを生成
QUERY_HASH=$(echo -n "$QUERY" | sha256sum | awk '{print $1}')
CACHE_FILE="$CACHE_DIR/${QUERY_HASH}.md"
CACHE_META="$CACHE_DIR/${QUERY_HASH}.meta"

# キャッシュの有効性チェック
is_cache_valid() {
    if [ ! -f "$CACHE_FILE" ] || [ ! -f "$CACHE_META" ]; then
        return 1
    fi

    # キャッシュの年齢をチェック（時間単位）
    local cache_age=$(( ($(date +%s) - $(stat -c %Y "$CACHE_FILE")) / 3600 ))
    if [ "$cache_age" -ge "$CACHE_TTL_HOURS" ]; then
        return 1
    fi

    # ファイルが空でないことを確認
    if [ ! -s "$CACHE_FILE" ]; then
        return 1
    fi

    return 0
}

# 出力の完全性を検証
validate_output() {
    local file="$1"

    # ファイルが存在し、空でないことを確認
    if [ ! -s "$file" ]; then
        echo "[ERROR] Output file is empty" >&2
        return 1
    fi

    # 切り詰めパターンを検出
    if grep -q '\[.*content truncated.*\]' "$file" 2>/dev/null; then
        echo "[WARNING] Output was truncated" >&2
        # 切り詰めは警告のみ（エラーにはしない）
    fi

    # エラーパターンを検出
    if grep -qE '^(Error:|ERROR:|Exception:)' "$file" 2>/dev/null; then
        echo "[ERROR] Error pattern detected in output" >&2
        return 1
    fi

    return 0
}

# Gemini を呼び出し（リトライ付き）
call_gemini() {
    local query="$1"
    local output="$2"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        echo "[INFO] Calling Gemini (attempt $attempt/$MAX_RETRIES)..." >&2

        # Gemini CLI を呼び出し
        if gemini -p "$query" > "$output" 2> "${output}.err"; then
            # 出力を検証
            if validate_output "$output"; then
                rm -f "${output}.err"
                return 0
            fi
        fi

        # エラーログを確認
        if [ -f "${output}.err" ] && [ -s "${output}.err" ]; then
            echo "[ERROR] Gemini error:" >&2
            cat "${output}.err" >&2
        fi

        # リトライ
        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_RETRIES ]; then
            echo "[INFO] Retrying in ${RETRY_DELAY}s..." >&2
            sleep $RETRY_DELAY
        fi
    done

    echo "[ERROR] All retry attempts failed" >&2
    return 1
}

# メイン処理
main() {
    # キャッシュが有効ならそれを使用
    if is_cache_valid; then
        echo "[INFO] Using cached result (hash: ${QUERY_HASH:0:8}...)" >&2

        if [ -n "$OUTPUT_FILE" ]; then
            cp "$CACHE_FILE" "$OUTPUT_FILE"
            echo "$OUTPUT_FILE"
        else
            cat "$CACHE_FILE"
        fi
        return 0
    fi

    echo "[INFO] Cache miss or expired, calling Gemini..." >&2

    # 一時ファイルに出力
    local tmp_file=$(mktemp)
    trap "rm -f '$tmp_file' '${tmp_file}.err'" EXIT

    # Gemini を呼び出し
    if ! call_gemini "$QUERY" "$tmp_file"; then
        echo "[ERROR] Failed to get response from Gemini" >&2
        exit 1
    fi

    # キャッシュを更新
    cp "$tmp_file" "$CACHE_FILE"
    echo "$(date -Iseconds)" > "$CACHE_META"
    echo "query_hash=$QUERY_HASH" >> "$CACHE_META"

    # 出力
    if [ -n "$OUTPUT_FILE" ]; then
        cp "$tmp_file" "$OUTPUT_FILE"
        echo "$OUTPUT_FILE"
    else
        cat "$tmp_file"
    fi
}

main
