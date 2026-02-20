#!/bin/bash
# shogun-write-guard.sh - 将軍（Shogun）書き込みガード
# Identity分離設計書v3 セクション7 準拠（忍び#7反映）
# shogunロール固有の書き込みガードとして再定義。

set -euo pipefail

HOOK_NAME="shogun-write-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lib/hook_common.sh"

# ロールチェック: shogunロール以外は即exit 0
check_role_match "shogun"

# stdinからファイルパス取得
FILE_PATH=$(read_filepath_from_stdin)

# file_pathが取得できない場合は通す
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# パス正規化
NORM_PATH=$(normalize_path "$FILE_PATH")

# queue/配下のyamlファイルのみ許可
if [[ "$NORM_PATH" == *"/queue/"* && "$NORM_PATH" == *".yaml" ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_ALLOW_QUEUE" "path=$NORM_PATH" "allow"
    exit 0
fi


# 将軍メモリファイルは許可
if [[ "$(basename "$NORM_PATH")" == "shogun.md" ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_ALLOW_OWN_MEMORY" "path=$NORM_PATH" "allow"
    exit 0
fi

# 他役職メモリ禁止
BASENAME=$(basename "$NORM_PATH")
if [[ "$BASENAME" == "karo.md" || "$BASENAME" == "ashigaru.md" || "$BASENAME" == "denrei.md" ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_DENY_OTHER_MEMORY" "path=$NORM_PATH" "deny"
    echo "将軍は他役職のメモリファイルを編集できません。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# それ以外は全て拒否
hook_log "$HOOK_NAME" "SHOGUN_WRITE_DEFAULT_DENY" "path=$NORM_PATH" "deny"
echo "将軍はqueue/配下のYAMLファイルのみ編集可能です。" >&2
echo "対象ファイル: $FILE_PATH" >&2
echo "他のファイルは家老経由で足軽に委譲してください。" >&2
exit 2
