#!/bin/bash
# ashigaru-write-guard.sh - 足軽書き込みガード
# Identity分離設計書v3 セクション7 準拠
# システム設定・instructions禁止、メモリ保護(ashigaru.mdのみ許可)
# v2 #7反映: queue/inbox/shogun.yaml への直接書き込みもブロック

set -euo pipefail

HOOK_NAME="ashigaru-write-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: ashigaruロール以外は即exit 0
check_role_match "ashigaru"

# stdinからファイルパス取得
FILE_PATH=$(read_filepath_from_stdin)

# file_pathが取得できない場合は通す
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# パス正規化（シンボリックリンク・../等による迂回防止）
NORM_PATH=$(normalize_path "$FILE_PATH")

# === 禁止リスト ===

# 将軍inbox直接書き込み禁止（v2 #7反映）
if [[ "$NORM_PATH" == *"/queue/inbox/shogun.yaml" ]]; then
    hook_log "$HOOK_NAME" "ASHIGARU_WRITE_DENY_SHOGUN_INBOX" "path=$NORM_PATH" "deny"
    echo "足軽は将軍のinboxに直接書き込めません。家老経由で報告してください。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# システム設定禁止
if [[ "$NORM_PATH" == *"/.claude/settings"* || "$NORM_PATH" == *"/.claude/hooks/"* || "$NORM_PATH" == *"/.claude/agents/"* ]]; then
    hook_log "$HOOK_NAME" "ASHIGARU_WRITE_DENY_SYSTEM" "path=$NORM_PATH" "deny"
    echo "足軽はシステム設定を編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# instructions禁止
if [[ "$NORM_PATH" == *"/instructions/"* ]]; then
    hook_log "$HOOK_NAME" "ASHIGARU_WRITE_DENY_INSTRUCTIONS" "path=$NORM_PATH" "deny"
    echo "足軽は指示書を編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# 他役職メモリ禁止
BASENAME=$(basename "$NORM_PATH")
if [[ "$BASENAME" == "shogun.md" || "$BASENAME" == "karo.md" || "$BASENAME" == "denrei.md" ]]; then
    hook_log "$HOOK_NAME" "ASHIGARU_WRITE_DENY_OTHER_MEMORY" "path=$NORM_PATH" "deny"
    echo "足軽は他役職のメモリファイルを編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# デフォルト許可（足軽はソースコード編集が主務）
exit 0
