#!/bin/bash
# hook_common.sh - Hook共有ライブラリ
# Identity分離設計書v3 セクション10 準拠
#
# 全hookスクリプトからsourceして使用。
# sourceした時点で自動的に verify_hook_common_integrity() + verify_epoch() を実行。
#
# 主要関数:
#   get_role()                    - pane_role_map.yaml参照で公式ロール解決
#   check_role_match(target_role) - 非担当ロールは即exit 0
#   verify_epoch()                - session.epochとmap epochの一致検証
#   verify_hook_common_integrity()- 自己ハッシュ検証
#   hook_log()                    - 構造化ログ出力
#   read_command_from_stdin()     - stdin JSONからコマンド取得
#   read_filepath_from_stdin()    - stdin JSONからファイルパス取得
#   normalize_path()              - realpathでパス正規化

# プロジェクトルートの解決
HOOK_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PROJECT_DIR="$(cd "$HOOK_COMMON_DIR/../.." && pwd)"

# ファイルパス定数
HOOK_MAP_FILE="$HOOK_PROJECT_DIR/config/pane_role_map.yaml"
HOOK_MAP_HASH_FILE="$HOOK_MAP_FILE.sha256"
HOOK_MAP_LOCK_FILE="$HOOK_MAP_FILE.lock"
HOOK_EPOCH_FILE="$HOOK_PROJECT_DIR/config/session.epoch"
HOOK_COMMON_HASH_FILE="$HOOK_COMMON_DIR/hook_common.sh.sha256"

# === 構造化ログ ===
hook_log() {
    local hook_name="$1"
    local rule="$2"
    local detail="$3"
    local decision="$4"
    echo "[HOOK] $hook_name | rule=$rule | $detail | decision=$decision" >&2
}

# === verify_hook_common_integrity ===
# hook_common.sh自身のsha256ハッシュを検証
# 改ざん検出時はexit 2
verify_hook_common_integrity() {
    if [[ -f "$HOOK_COMMON_HASH_FILE" ]]; then
        local current_hash expected_hash
        current_hash=$(sha256sum "$HOOK_COMMON_DIR/hook_common.sh" 2>/dev/null | awk '{print $1}')
        expected_hash=$(awk '{print $1}' "$HOOK_COMMON_HASH_FILE" 2>/dev/null)
        if [[ -n "$current_hash" && -n "$expected_hash" && "$current_hash" != "$expected_hash" ]]; then
            echo "[FATAL] hook_common.sh integrity check failed — tampering detected" >&2
            exit 2
        fi
    fi
    # ハッシュファイルが存在しない場合は検証スキップ（初回起動時/開発中）
}

# === verify_epoch ===
# pane_role_map.yamlのepochとconfig/session.epochの一致を検証
# 不一致時はexit 2
verify_epoch() {
    # session.epochファイルが存在しない場合はスキップ（初回起動時）
    if [[ ! -f "$HOOK_EPOCH_FILE" ]]; then
        return 0
    fi
    if [[ ! -f "$HOOK_MAP_FILE" ]]; then
        return 0
    fi

    local session_epoch map_epoch
    session_epoch=$(cat "$HOOK_EPOCH_FILE" 2>/dev/null | tr -d '[:space:]')
    map_epoch=$(grep -E "^epoch:" "$HOOK_MAP_FILE" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]' || true)

    if [[ -n "$session_epoch" && -n "$map_epoch" && "$session_epoch" != "$map_epoch" ]]; then
        echo "[FATAL] epoch mismatch: session=$session_epoch map=$map_epoch — fail-closed" >&2
        exit 2
    fi
}

# === get_role ===
# 現在のpane IDからpane_role_map.yamlを参照して公式ロールを解決
# Trust Anchor: pane_role_map.yaml（@agent_idは補助のみ）
# 失敗時はexit 2
get_role() {
    # tmux外判定
    if [[ -z "${TMUX:-}" ]] || [[ -z "${TMUX_PANE:-}" ]]; then
        echo "[ERROR] get_role: not in tmux — fail-closed" >&2
        exit 2
    fi

    local pane_id="$TMUX_PANE"

    # マッピングファイル存在チェック
    if [[ ! -f "$HOOK_MAP_FILE" ]]; then
        echo "[ERROR] get_role: pane_role_map.yaml not found — fail-closed" >&2
        exit 2
    fi

    # sha256整合性チェック
    if [[ -f "$HOOK_MAP_HASH_FILE" ]]; then
        if ! sha256sum -c "$HOOK_MAP_HASH_FILE" --status 2>/dev/null; then
            echo "[ERROR] get_role: pane_role_map.yaml integrity check failed — fail-closed" >&2
            exit 2
        fi
    fi

    # 共有ロックでマッピング読み取り
    local role=""
    exec 200>"$HOOK_MAP_LOCK_FILE"
    flock -s 200
    role=$(grep -E "^[[:space:]]*\"?${pane_id}\"?:" "$HOOK_MAP_FILE" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d ' "' || true)
    exec 200>&-

    if [[ -z "$role" ]]; then
        echo "[ERROR] get_role: pane $pane_id not found in map — fail-closed" >&2
        exit 2
    fi

    # @agent_id cross-check（補助、権限判定の根拠としない）
    local agent_id
    agent_id=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")
    if [[ -n "$agent_id" ]]; then
        local agent_base
        agent_base=$(echo "$agent_id" | sed 's/[0-9]*$//')
        if [[ "$agent_base" != "$role" && "$agent_id" != "$role" ]]; then
            echo "[WARNING] get_role: @agent_id='$agent_id' != map_role='$role' — trusting map" >&2
        fi
    fi

    echo "$role"
}

# === check_role_match ===
# 解決したロールがtarget_roleと一致しない場合はexit 0（即終了 = allow）
# 一致する場合は何もしない（呼び出し元に制御を返す）
check_role_match() {
    local target_role="$1"
    # tmux外の場合: hookスキップ
    if [[ -z "${TMUX:-}" ]] || [[ -z "${TMUX_PANE:-}" ]]; then
        exit 0
    fi

    # pane_role_map.yamlが存在しない場合: hookスキップ
    if [[ ! -f "$HOOK_MAP_FILE" ]]; then
        exit 0
    fi
    local current_role
    current_role=$(get_role)

    if [[ "$current_role" != "$target_role" ]]; then
        # 非担当ロール → このhookは無関係なので即終了（allow）
        exit 0
    fi
    # 担当ロール → 制御を呼び出し元に返す
}

# === stdinからJSON読み取り(コマンド取得) ===
# 注意: stdinは一度しか読めないため、この関数は1回のhook実行で1回のみ呼ぶこと
read_command_from_stdin() {
    local cmd=""
    if [[ ! -t 0 ]]; then
        local json_input
        json_input=$(cat)
        if [[ -n "$json_input" ]] && command -v jq &>/dev/null; then
            cmd=$(echo "$json_input" | jq -r '.tool_input.command // .parameters.command // .command // empty' 2>/dev/null || echo "")
        fi
    fi
    echo "$cmd"
}

# === stdinからJSON読み取り(ファイルパス取得) ===
# 注意: stdinは一度しか読めないため、この関数は1回のhook実行で1回のみ呼ぶこと
read_filepath_from_stdin() {
    local filepath=""
    if [[ ! -t 0 ]]; then
        local json_input
        json_input=$(cat)
        if [[ -n "$json_input" ]] && command -v jq &>/dev/null; then
            filepath=$(echo "$json_input" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null || echo "")
        fi
    fi
    echo "$filepath"
}

# === パス正規化 ===
# realpathで正規パスを取得。シンボリックリンク・../等による迂回を防止
normalize_path() {
    local path="$1"
    if [[ -e "$path" ]]; then
        realpath "$path" 2>/dev/null || echo "$path"
    else
        # ファイルが存在しない場合は親ディレクトリをrealpathして結合
        local dir base
        dir=$(dirname "$path")
        base=$(basename "$path")
        if [[ -d "$dir" ]]; then
            echo "$(realpath "$dir" 2>/dev/null)/$base"
        else
            echo "$path"
        fi
    fi
}

# === 自動実行: sourceされた時点で検証 ===
verify_hook_common_integrity
verify_epoch
