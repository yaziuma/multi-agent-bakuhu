#!/bin/bash
# selftest_hooks.sh - Hook自己テストスクリプト
# Identity分離設計書v3 セクション9 準拠
# 起動時にポリシー整合性を検証するセルフテスト
#
# Usage: bash scripts/selftest_hooks.sh
# Exit: 0=all pass, 1=warning (non-fatal), 2=fatal (abort session)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
POLICY_DIR="$PROJECT_DIR/.claude/hooks/policies"
HOOK_DIR="$PROJECT_DIR/.claude/hooks"
LOG_FILE="$PROJECT_DIR/logs/selftest_failure.log"
HOOK_COMMON="$PROJECT_DIR/scripts/lib/hook_common.sh"

# 色付きログ
log_pass() { echo -e "\033[1;32m[PASS]\033[0m $1"; }
log_fail() { echo -e "\033[1;31m[FAIL]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_info() { echo -e "\033[1;36m[INFO]\033[0m $1"; }

ERRORS=0
WARNINGS=0

echo ""
echo "============================================"
echo " Identity分離 Hook セルフテスト"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# === Test 1: ポリシーファイルの存在チェック ===
log_info "Test 1: ポリシーファイル存在チェック"
REQUIRED_POLICIES=(
    "policy_schema.json"
    "shogun_policy.yaml"
    "karo_policy.yaml"
    "ashigaru_policy.yaml"
    "denrei_policy.yaml"
    "global_policy.yaml"
)
for policy in "${REQUIRED_POLICIES[@]}"; do
    if [[ -f "$POLICY_DIR/$policy" ]]; then
        log_pass "$policy 存在確認"
    else
        log_fail "$policy が見つかりません"
        ((ERRORS++))
    fi
done
echo ""

# === Test 2: Hookスクリプトの存在・実行権限チェック ===
log_info "Test 2: Hookスクリプト存在・実行権限チェック"
REQUIRED_HOOKS=(
    "shogun-guard.sh"
    "shogun-write-guard.sh"
    "karo-guard.sh"
    "karo-write-guard.sh"
    "ashigaru-guard.sh"
    "ashigaru-write-guard.sh"
    "denrei-guard.sh"
    "denrei-write-guard.sh"
    "global-guard.sh"
)
for hook in "${REQUIRED_HOOKS[@]}"; do
    if [[ -f "$HOOK_DIR/$hook" ]]; then
        if [[ -x "$HOOK_DIR/$hook" ]]; then
            log_pass "$hook 存在+実行権限OK"
        else
            log_fail "$hook 実行権限なし"
            ((ERRORS++))
        fi
    else
        log_fail "$hook が見つかりません"
        ((ERRORS++))
    fi
done
echo ""

# === Test 3: hook_common.sh の存在チェック ===
log_info "Test 3: hook_common.sh チェック"
if [[ -f "$HOOK_COMMON" ]]; then
    log_pass "hook_common.sh 存在確認"
    # 必須関数の存在チェック
    REQUIRED_FUNCTIONS=("get_role" "check_role_match" "verify_epoch" "verify_hook_common_integrity" "hook_log" "read_command_from_stdin" "read_filepath_from_stdin" "normalize_path")
    for func in "${REQUIRED_FUNCTIONS[@]}"; do
        if grep -q "^${func}()" "$HOOK_COMMON" 2>/dev/null; then
            log_pass "  関数 $func() 定義あり"
        else
            log_fail "  関数 $func() が見つかりません"
            ((ERRORS++))
        fi
    done
else
    log_fail "hook_common.sh が見つかりません"
    ((ERRORS++))
fi
echo ""

# === Test 4: コアスクリプトの存在チェック ===
log_info "Test 4: コアスクリプトチェック"
CORE_SCRIPTS=(
    "scripts/get_pane_id.sh"
    "scripts/get_agent_role.sh"
)
for script in "${CORE_SCRIPTS[@]}"; do
    FULL_PATH="$PROJECT_DIR/$script"
    if [[ -f "$FULL_PATH" ]]; then
        if [[ -x "$FULL_PATH" ]]; then
            log_pass "$script 存在+実行権限OK"
        else
            log_fail "$script 実行権限なし"
            ((ERRORS++))
        fi
    else
        log_fail "$script が見つかりません"
        ((ERRORS++))
    fi
done
echo ""

# === Test 5: ポリシーYAMLのスキーマ検証（簡易版） ===
log_info "Test 5: ポリシーYAML構造検証（簡易）"
POLICY_YAMLS=(
    "shogun_policy.yaml"
    "karo_policy.yaml"
    "ashigaru_policy.yaml"
    "denrei_policy.yaml"
    "global_policy.yaml"
)
for policy in "${POLICY_YAMLS[@]}"; do
    PFILE="$POLICY_DIR/$policy"
    if [[ ! -f "$PFILE" ]]; then
        continue
    fi

    # 必須フィールドチェック
    HAS_ROLE=$(grep -c "^role:" "$PFILE" 2>/dev/null || echo 0)
    HAS_VERSION=$(grep -c "^version:" "$PFILE" 2>/dev/null || echo 0)
    HAS_RULES=$(grep -c "^rules:" "$PFILE" 2>/dev/null || echo 0)

    if [[ "$HAS_ROLE" -ge 1 && "$HAS_VERSION" -ge 1 && "$HAS_RULES" -ge 1 ]]; then
        log_pass "$policy: 必須フィールド(role/version/rules)あり"
    else
        log_fail "$policy: 必須フィールド欠如 (role=$HAS_ROLE, version=$HAS_VERSION, rules=$HAS_RULES)"
        ((ERRORS++))
    fi

    # ルールにid/action/patternがあるか
    RULE_COUNT=$(grep -c "^  - id:" "$PFILE" 2>/dev/null || echo 0)
    ACTION_COUNT=$(grep -c "action:" "$PFILE" 2>/dev/null || echo 0)
    PATTERN_COUNT=$(grep -c "pattern:" "$PFILE" 2>/dev/null || echo 0)

    if [[ "$RULE_COUNT" -ge 1 && "$ACTION_COUNT" -ge 1 && "$PATTERN_COUNT" -ge 1 ]]; then
        log_pass "$policy: ルール定義あり ($RULE_COUNT rules)"
    else
        log_warn "$policy: ルール定義が不十分"
        ((WARNINGS++))
    fi
done
echo ""

# === Test 6: pane_role_map.yaml チェック（実行時のみ） ===
log_info "Test 6: pane_role_map.yaml チェック"
MAP_FILE="$PROJECT_DIR/config/pane_role_map.yaml"
if [[ -f "$MAP_FILE" ]]; then
    log_pass "pane_role_map.yaml 存在確認"

    # epoch存在チェック
    if grep -q "^epoch:" "$MAP_FILE" 2>/dev/null; then
        MAP_EPOCH=$(grep "^epoch:" "$MAP_FILE" | awk '{print $2}')
        log_pass "  epoch: $MAP_EPOCH"
    else
        log_warn "  epoch フィールドなし（初回起動前？）"
        ((WARNINGS++))
    fi

    # sha256チェック
    if [[ -f "$MAP_FILE.sha256" ]]; then
        if sha256sum -c "$MAP_FILE.sha256" --status 2>/dev/null; then
            log_pass "  sha256整合性OK"
        else
            log_fail "  sha256整合性不一致 — 改ざんの可能性"
            ((ERRORS++))
        fi
    else
        log_warn "  sha256ファイルなし（初回起動前？）"
        ((WARNINGS++))
    fi

    # session.epochとの一致チェック
    EPOCH_FILE="$PROJECT_DIR/config/session.epoch"
    if [[ -f "$EPOCH_FILE" ]]; then
        SESSION_EPOCH=$(cat "$EPOCH_FILE" | tr -d '[:space:]')
        if [[ -n "$MAP_EPOCH" && "$MAP_EPOCH" == "$SESSION_EPOCH" ]]; then
            log_pass "  epoch一致: map=$MAP_EPOCH session=$SESSION_EPOCH"
        elif [[ -n "$MAP_EPOCH" ]]; then
            log_fail "  epoch不一致: map=$MAP_EPOCH session=$SESSION_EPOCH"
            ((ERRORS++))
        fi
    else
        log_warn "  session.epoch なし（初回起動前？）"
        ((WARNINGS++))
    fi
else
    log_warn "pane_role_map.yaml なし（セッション未起動）"
    ((WARNINGS++))
fi
echo ""

# === Test 7: hook_common.sh 整合性チェック ===
log_info "Test 7: hook_common.sh 整合性チェック"
if [[ -f "$HOOK_COMMON" ]]; then
    if [[ -f "$HOOK_COMMON.sha256" ]]; then
        if sha256sum -c "$HOOK_COMMON.sha256" --status 2>/dev/null; then
            log_pass "hook_common.sh sha256整合性OK"
        else
            log_fail "hook_common.sh sha256整合性不一致 — 改ざんの可能性"
            ((ERRORS++))
        fi
    else
        log_warn "hook_common.sh.sha256 なし（初回起動前？）"
        ((WARNINGS++))
    fi

    # パーミッションチェック
    PERMS=$(stat -c '%a' "$HOOK_COMMON" 2>/dev/null || echo "unknown")
    if [[ "$PERMS" == "444" ]]; then
        log_pass "hook_common.sh パーミッション: $PERMS (read-only)"
    else
        log_warn "hook_common.sh パーミッション: $PERMS (期待値: 444)"
        ((WARNINGS++))
    fi
fi
echo ""

# === 結果サマリ ===
echo "============================================"
echo " テスト結果サマリ"
echo "============================================"
echo "  エラー:   $ERRORS"
echo "  警告:     $WARNINGS"
echo ""

if [[ $ERRORS -gt 0 ]]; then
    log_fail "致命的なエラーがあります。セッション起動を中断してください。"
    # ログ出力
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "selftest failed at $(date '+%Y-%m-%d %H:%M:%S'): $ERRORS errors, $WARNINGS warnings" >> "$LOG_FILE"

    # === フォールバック: gitで安定版ポリシーへのロールバック試行 ===
    log_info "フォールバック: 安定版ポリシーへのロールバックを試行..."
    LAST_GOOD_COMMIT=$(cd "$PROJECT_DIR" && git log --oneline -10 -- .claude/hooks/policies/ 2>/dev/null | head -1 | awk '{print $1}')
    if [[ -n "$LAST_GOOD_COMMIT" ]]; then
        log_info "  直近の安定版commit: $LAST_GOOD_COMMIT"
        log_info "  手動ロールバック: git checkout $LAST_GOOD_COMMIT -- .claude/hooks/policies/"
        log_info "  自動ロールバックは安全のため無効化しています。上記コマンドを手動で実行してください。"
    else
        log_warn "  ポリシーのgit履歴が見つかりません"
    fi

    exit 2
elif [[ $WARNINGS -gt 0 ]]; then
    log_warn "警告がありますが、セッション起動は可能です。"
    exit 0
else
    log_pass "全テストパス。Identity分離基盤は正常です。"
    exit 0
fi
