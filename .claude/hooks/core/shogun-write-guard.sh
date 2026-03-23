#!/bin/bash
# shogun-write-guard.sh - 将軍（Shogun）書き込みガード
# Identity分離設計書v3 セクション7 準拠（忍び#7反映）
# shogunロール固有の書き込みガードとして再定義。
# cmd_424: symlink解決バグ修正 + パストラバーサル防御強化

set -euo pipefail

HOOK_NAME="shogun-write-guard"

# hook_common.sh をsource（自動的に整合性検証+エポック検証）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/lib/hook_common.sh"

# ロールチェック: shogunロール以外は即exit 0
check_role_match "shogun"

# stdinからファイルパス取得
FILE_PATH=$(read_filepath_from_stdin)

# file_pathが取得できない場合は通す
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# パス正規化（symlink解決版）
NORM_PATH=$(normalize_path "$FILE_PATH")

# 論理パス正規化（symlink非解決、../のみ解決）
# queue/inbox がsymlinkの場合でも論理パスで queue/ 配下と判定するため
LOGICAL_DIR=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd) || LOGICAL_DIR=""
if [[ -n "$LOGICAL_DIR" ]]; then
    LOGICAL_NORM="$LOGICAL_DIR/$(basename "$FILE_PATH")"
else
    LOGICAL_NORM="$FILE_PATH"
fi

# パストラバーサル防御: ../を含むパスは即拒否（正規化失敗時のフォールバック対策）
if [[ "$NORM_PATH" == *".."* || "$LOGICAL_NORM" == *".."* ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_DENY_TRAVERSAL" "path=$FILE_PATH" "deny"
    echo "パストラバーサルが検出されました。" >&2
    echo "対象: $FILE_PATH" >&2
    exit 2
fi

# queue/配下のyamlファイル判定
# HOOK_PROJECT_DIR前方一致で厳密にプロジェクトスコープ内のqueue/のみ許可
QUEUE_PREFIX="$HOOK_PROJECT_DIR/queue/"
if [[ "$NORM_PATH" == "$QUEUE_PREFIX"* && "$NORM_PATH" == *".yaml" ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_ALLOW_QUEUE" "path=$NORM_PATH" "allow"
    exit 0
fi

# symlink解決前の論理パスでも判定（queue/inbox symlink対応）
# ../解決済みかつプロジェクト前方一致で、パストラバーサル攻撃を防止
if [[ "$LOGICAL_NORM" == "$QUEUE_PREFIX"* && "$LOGICAL_NORM" == *".yaml" ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_ALLOW_QUEUE_LOGICAL" "path=$LOGICAL_NORM" "allow"
    exit 0
fi

# 将軍メモリファイルは許可
if [[ "$(basename "$NORM_PATH")" == "shogun.md" ]]; then
    hook_log "$HOOK_NAME" "SHOGUN_WRITE_ALLOW_OWN_MEMORY" "path=$NORM_PATH" "allow"
    exit 0
fi

  # Claude Code auto-memory ディレクトリは許可
  CLAUDE_MEMORY_DIR="$HOME/.claude/projects/$(echo "$HOOK_PROJECT_DIR" | sed 's|/|-|g')/memory/"
  if [[ "$NORM_PATH" == "$CLAUDE_MEMORY_DIR"* ]]; then
      hook_log "$HOOK_NAME" "SHOGUN_WRITE_ALLOW_CLAUDE_MEMORY" "path=$NORM_PATH" "allow"
      exit 0
  fi

# 他役職メモリ禁止
# bakuhu-alignment/は一時バイパス（Phase 1完了後に復元）
if [[ "$NORM_PATH" == */bakuhu-alignment/* ]]; then
    exit 0
fi
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
