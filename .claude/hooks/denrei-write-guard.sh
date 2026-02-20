#!/bin/bash
# denrei-write-guard.sh - 伝令書き込みガード
# Identity分離設計書v3 セクション7 準拠
# ソースコード・.claude/・instructions禁止、queue/*.yaml許可、デフォルトブロック

set -euo pipefail

HOOK_NAME="denrei-write-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: denreiロール以外は即exit 0
check_role_match "denrei"

# stdinからファイルパス取得
FILE_PATH=$(read_filepath_from_stdin)

# file_pathが取得できない場合は通す
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# パス正規化（シンボリックリンク・../等による迂回防止）
NORM_PATH=$(normalize_path "$FILE_PATH")

# === 許可リスト（最優先） ===

# queue配下のYAML許可
if [[ "$NORM_PATH" == *"/queue/"* && "$NORM_PATH" == *".yaml" ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_ALLOW_QUEUE" "path=$NORM_PATH" "allow"
    exit 0
fi

# 伝令メモリファイル許可
if [[ "$(basename "$NORM_PATH")" == "denrei.md" ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_ALLOW_MEMORY" "path=$NORM_PATH" "allow"
    exit 0
fi

# queue配下のレポート（非YAML含む）許可
if [[ "$NORM_PATH" == *"/queue/denrei/"* ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_ALLOW_DENREI_QUEUE" "path=$NORM_PATH" "allow"
    exit 0
fi

# queue/shinobi配下（忍び報告）許可
if [[ "$NORM_PATH" == *"/queue/shinobi/"* ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_ALLOW_SHINOBI" "path=$NORM_PATH" "allow"
    exit 0
fi

# === 禁止リスト ===

# ソースコード禁止
if [[ "$NORM_PATH" =~ \.(py|js|ts|jsx|tsx|html|css|scss)$ ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_DENY_SOURCE" "path=$NORM_PATH" "deny"
    echo "伝令はソースコードを編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# .claude/配下禁止
if [[ "$NORM_PATH" == *"/.claude/"* ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_DENY_CLAUDE_DIR" "path=$NORM_PATH" "deny"
    echo "伝令は.claude/配下を編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# instructions禁止
if [[ "$NORM_PATH" == *"/instructions/"* ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_DENY_INSTRUCTIONS" "path=$NORM_PATH" "deny"
    echo "伝令は指示書を編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# 他役職メモリ禁止
BASENAME=$(basename "$NORM_PATH")
if [[ "$BASENAME" == "shogun.md" || "$BASENAME" == "karo.md" || "$BASENAME" == "ashigaru.md" ]]; then
    hook_log "$HOOK_NAME" "DENREI_WRITE_DENY_OTHER_MEMORY" "path=$NORM_PATH" "deny"
    echo "伝令は他役職のメモリファイルを編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# デフォルトブロック（伝令は限定的な書き込みのみ許可）
hook_log "$HOOK_NAME" "DENREI_WRITE_DEFAULT_DENY" "path=$NORM_PATH" "deny"
echo "伝令は許可リスト外のファイルを編集できません。" >&2
echo "対象: $FILE_PATH" >&2
exit 2
