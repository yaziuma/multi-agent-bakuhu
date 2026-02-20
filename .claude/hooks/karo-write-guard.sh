#!/bin/bash
# karo-write-guard.sh - 家老書き込みガード
# Identity分離設計書v3 セクション7 準拠
# ソースコード禁止、システム設定禁止、メモリ保護(karo.mdのみ許可)

set -euo pipefail

HOOK_NAME="karo-write-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: karoロール以外は即exit 0
check_role_match "karo"

# stdinからファイルパス取得
FILE_PATH=$(read_filepath_from_stdin)

# file_pathが取得できない場合は通す
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# パス正規化（シンボリックリンク・../等による迂回防止）
NORM_PATH=$(normalize_path "$FILE_PATH")

# === 許可リスト（最優先） ===

# queue配下のYAMLは許可
if [[ "$NORM_PATH" == *"/queue/"* && "$NORM_PATH" == *".yaml" ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_ALLOW_QUEUE" "path=$NORM_PATH" "allow"
    exit 0
fi

# dashboard.md は許可
if [[ "$NORM_PATH" == *"/dashboard.md" ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_ALLOW_DASHBOARD" "path=$NORM_PATH" "allow"
    exit 0
fi

# config配下は許可
if [[ "$NORM_PATH" == *"/config/"* ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_ALLOW_CONFIG" "path=$NORM_PATH" "allow"
    exit 0
fi

# 家老メモリファイルは許可
if [[ "$(basename "$NORM_PATH")" == "karo.md" ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_ALLOW_MEMORY" "path=$NORM_PATH" "allow"
    exit 0
fi

# MEMORY.md（共有メモリ）は許可
if [[ "$(basename "$NORM_PATH")" == "MEMORY.md" ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_ALLOW_SHARED_MEMORY" "path=$NORM_PATH" "allow"
    exit 0
fi

# === 禁止リスト ===

# ソースコード禁止
if [[ "$NORM_PATH" =~ \.(py|js|ts|jsx|tsx|html|css|scss)$ ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_DENY_SOURCE" "path=$NORM_PATH" "deny"
    echo "家老はソースコードを直接編集できません。足軽に委譲してください。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# システム設定禁止
if [[ "$NORM_PATH" == *"/.claude/settings"* || "$NORM_PATH" == *"/.claude/hooks/"* || "$NORM_PATH" == *"/.claude/agents/"* ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_DENY_SYSTEM" "path=$NORM_PATH" "deny"
    echo "家老はシステム設定を編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# 他役職メモリ禁止
BASENAME=$(basename "$NORM_PATH")
if [[ "$BASENAME" == "shogun.md" || "$BASENAME" == "ashigaru.md" || "$BASENAME" == "denrei.md" ]]; then
    hook_log "$HOOK_NAME" "KARO_WRITE_DENY_OTHER_MEMORY" "path=$NORM_PATH" "deny"
    echo "家老は他役職のメモリファイルを編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# デフォルト許可（家老はqueueやdashboard以外にもログ等を書く場合がある）
exit 0
