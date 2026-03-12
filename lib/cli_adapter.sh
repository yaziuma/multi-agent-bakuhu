#!/usr/bin/env bash
# cli_adapter.sh — CLI抽象化レイヤー
# Multi-CLI統合設計書 (reports/design_multi_cli_support.md) §2.2 準拠
#
# 提供関数:
#   get_cli_type(agent_id)                  → "claude" | "codex" | "copilot" | "kimi"
#   build_cli_command(agent_id)             → 完全なコマンド文字列
#   get_instruction_file(agent_id [,cli_type]) → 指示書パス
#   validate_cli_availability(cli_type)     → 0=OK, 1=NG
#   get_agent_model(agent_id)               → "opus" | "sonnet" | "haiku" | "k2.5"

# プロジェクトルートを基準にsettings.yamlのパスを解決
CLI_ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_ADAPTER_PROJECT_ROOT="$(cd "${CLI_ADAPTER_DIR}/.." && pwd)"
CLI_ADAPTER_SETTINGS="${CLI_ADAPTER_SETTINGS:-${CLI_ADAPTER_PROJECT_ROOT}/config/settings.yaml}"

# 許可されたCLI種別
CLI_ADAPTER_ALLOWED_CLIS="claude codex copilot kimi"

# --- 内部ヘルパー ---

# _cli_adapter_read_yaml key [fallback]
# python3でsettings.yamlから値を読み取る
_cli_adapter_read_yaml() {
    local key_path="$1"
    local fallback="${2:-}"
    local result
    result=$(python3 -c "
import yaml, sys
try:
    with open('${CLI_ADAPTER_SETTINGS}') as f:
        cfg = yaml.safe_load(f) or {}
    keys = '${key_path}'.split('.')
    val = cfg
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k)
        else:
            val = None
            break
    if val is not None:
        print(val)
    else:
        print('${fallback}')
except Exception:
    print('${fallback}')
" 2>/dev/null)
    if [[ -z "$result" ]]; then
        echo "$fallback"
    else
        echo "$result"
    fi
}

# _cli_adapter_is_valid_cli cli_type
# 許可されたCLI種別かチェック
_cli_adapter_is_valid_cli() {
    local cli_type="$1"
    local allowed
    for allowed in $CLI_ADAPTER_ALLOWED_CLIS; do
        [[ "$cli_type" == "$allowed" ]] && return 0
    done
    return 1
}

# --- 公開API ---

# get_cli_type(agent_id)
# 指定エージェントが使用すべきCLI種別を返す
# フォールバック: cli.agents.{id}.type → cli.agents.{id}(文字列) → cli.default → "claude"
get_cli_type() {
    local agent_id="$1"
    if [[ -z "$agent_id" ]]; then
        echo "claude"
        return 0
    fi

    local result
    result=$(python3 -c "
import yaml, sys
try:
    with open('${CLI_ADAPTER_SETTINGS}') as f:
        cfg = yaml.safe_load(f) or {}
    cli = cfg.get('cli', {})
    if not isinstance(cli, dict):
        print('claude'); sys.exit(0)
    agents = cli.get('agents', {})
    if not isinstance(agents, dict):
        print(cli.get('default', 'claude') if cli.get('default', 'claude') in ('claude','codex','copilot','kimi') else 'claude')
        sys.exit(0)
    agent_cfg = agents.get('${agent_id}')
    if isinstance(agent_cfg, dict):
        t = agent_cfg.get('type', '')
        if t in ('claude', 'codex', 'copilot', 'kimi'):
            print(t); sys.exit(0)
    elif isinstance(agent_cfg, str):
        if agent_cfg in ('claude', 'codex', 'copilot', 'kimi'):
            print(agent_cfg); sys.exit(0)
    default = cli.get('default', 'claude')
    if default in ('claude', 'codex', 'copilot', 'kimi'):
        print(default)
    else:
        print('claude', file=sys.stderr)
        print('claude')
except Exception as e:
    print('claude', file=sys.stderr)
    print('claude')
" 2>/dev/null)

    if [[ -z "$result" ]]; then
        echo "claude"
    else
        if ! _cli_adapter_is_valid_cli "$result"; then
            echo "[WARN] Invalid CLI type '$result' for agent '$agent_id'. Falling back to 'claude'." >&2
            echo "claude"
        else
            echo "$result"
        fi
    fi
}

# build_cli_command(agent_id)
# エージェントを起動するための完全なコマンド文字列を返す
build_cli_command() {
    local agent_id="$1"
    local cli_type
    cli_type=$(get_cli_type "$agent_id")
    local model
    model=$(get_agent_model "$agent_id")

    case "$cli_type" in
        claude)
            local cmd="claude"
            if [[ -n "$model" ]]; then
                cmd="$cmd --model $model"
            fi
            cmd="$cmd --dangerously-skip-permissions"
            echo "$cmd"
            ;;
        codex)
            echo "codex --dangerously-bypass-approvals-and-sandbox --no-alt-screen"
            ;;
        copilot)
            echo "copilot --yolo"
            ;;
        kimi)
            local cmd="kimi --yolo"
            if [[ -n "$model" ]]; then
                cmd="$cmd --model $model"
            fi
            echo "$cmd"
            ;;
        *)
            echo "claude --dangerously-skip-permissions"
            ;;
    esac
}

# get_instruction_file(agent_id [,cli_type])
# CLIが自動読込すべき指示書ファイルのパスを返す
get_instruction_file() {
    local agent_id="$1"
    local cli_type="${2:-$(get_cli_type "$agent_id")}"
    local role

    case "$agent_id" in
        shogun)    role="shogun" ;;
        karo)      role="karo" ;;
        ashigaru*) role="ashigaru" ;;
        *)
            echo "" >&2
            return 1
            ;;
    esac

    case "$cli_type" in
        claude)  echo "instructions/${role}.md" ;;
        codex)   echo "instructions/codex-${role}.md" ;;
        copilot) echo ".github/copilot-instructions-${role}.md" ;;
        kimi)    echo "instructions/generated/kimi-${role}.md" ;;
        *)       echo "instructions/${role}.md" ;;
    esac
}

# validate_cli_availability(cli_type)
# 指定CLIがシステムにインストールされているか確認
# 0=利用可能, 1=利用不可
validate_cli_availability() {
    local cli_type="$1"
    case "$cli_type" in
        claude)
            command -v claude &>/dev/null || {
                echo "[ERROR] Claude Code CLI not found. Install from https://claude.ai/download" >&2
                return 1
            }
            ;;
        codex)
            command -v codex &>/dev/null || {
                echo "[ERROR] OpenAI Codex CLI not found. Install with: npm install -g @openai/codex" >&2
                return 1
            }
            ;;
        copilot)
            command -v copilot &>/dev/null || {
                echo "[ERROR] GitHub Copilot CLI not found. Install with: brew install copilot-cli" >&2
                return 1
            }
            ;;
        kimi)
            if ! command -v kimi-cli &>/dev/null && ! command -v kimi &>/dev/null; then
                echo "[ERROR] Kimi CLI not found. Install from https://platform.moonshot.cn/" >&2
                return 1
            fi
            ;;
        *)
            echo "[ERROR] Unknown CLI type: '$cli_type'. Allowed: $CLI_ADAPTER_ALLOWED_CLIS" >&2
            return 1
            ;;
    esac
    return 0
}

# get_agent_model(agent_id)
# エージェントが使用すべきモデル名を返す
get_agent_model() {
    local agent_id="$1"

    # まずsettings.yamlのcli.agents.{id}.modelを確認
    local model_from_yaml
    model_from_yaml=$(_cli_adapter_read_yaml "cli.agents.${agent_id}.model" "")

    if [[ -n "$model_from_yaml" ]]; then
        echo "$model_from_yaml"
        return 0
    fi

    # 既存のmodelsセクションを確認
    local model_from_models
    model_from_models=$(_cli_adapter_read_yaml "models.${agent_id}" "")

    if [[ -n "$model_from_models" ]]; then
        echo "$model_from_models"
        return 0
    fi

    # デフォルトロジック（CLI種別に応じた初期値）
    local cli_type
    cli_type=$(get_cli_type "$agent_id")

    case "$cli_type" in
        kimi)
            # Kimi CLI用デフォルトモデル
            case "$agent_id" in
                shogun|karo)    echo "k2.5" ;;
                ashigaru*)      echo "k2.5" ;;
                *)              echo "k2.5" ;;
            esac
            ;;
        *)
            # Claude Code/Codex/Copilot用デフォルトモデル（kessen/heiji互換）
            case "$agent_id" in
                shogun|karo)    echo "opus" ;;
                ashigaru[1-4])  echo "sonnet" ;;
                ashigaru[5-8])  echo "opus" ;;
                *)              echo "sonnet" ;;
            esac
            ;;
    esac
}

# =============================================================================
# bloom_routing Phase 3 — Dynamic Model Routing
# 本家 lib/cli_adapter.sh L487-597, L1029-1156 からbakuhu向けに移植
# bakuhu適応: .venv不要(python3直呼び)、capability_tiers未定義時フォールバック、
#             cli.agents未定義時はpane_role_map.yamlからfallback
# =============================================================================

# get_recommended_model(bloom_level)
# bloom_levelに基づく推奨モデルを返す
# 引数: bloom_level — 整数(1-6) または Lプレフィックス付き(L1-L6) どちらも可
# 出力: "sonnet" | "opus" | モデル名 (capability_tiers定義時)
# 戻り値: 0=成功, 1=引数不正
get_recommended_model() {
    local bloom_level="$1"

    # Lプレフィックスを除去 (L4 → 4)
    bloom_level="${bloom_level#L}"
    bloom_level="${bloom_level#l}"

    # 範囲チェック
    if [[ ! "$bloom_level" =~ ^[1-6]$ ]]; then
        echo ""
        return 1
    fi

    local settings="${CLI_ADAPTER_SETTINGS:-${CLI_ADAPTER_PROJECT_ROOT}/config/settings.yaml}"

    # Python: capability_tiersが定義されていればそちらを優先、未定義の場合はbashフォールバック
    local result
    result=$(python3 -c "
import yaml, sys

def parse_bloom_range(key):
    '''parse 'L1-L3' -> [1,2,3], 'L4-L5' -> [4,5], 'L6' -> [6]'''
    key = key.strip()
    if '-' in key[1:]:
        parts = key.split('-')
        start = int(parts[0].lstrip('Ll'))
        end = int(parts[1].lstrip('Ll'))
        return list(range(start, end + 1))
    else:
        return [int(key.lstrip('Ll'))]

try:
    with open('${settings}') as f:
        cfg = yaml.safe_load(f) or {}
    tiers = cfg.get('capability_tiers')
    if not tiers or not isinstance(tiers, dict):
        sys.exit(0)  # フォールバックへ

    bloom = int('${bloom_level}')
    cost_priority = {'chatgpt_pro': 0, 'claude_max': 1}

    explicit_groups = cfg.get('available_cost_groups')
    if explicit_groups and isinstance(explicit_groups, list):
        allowed_groups = set(str(g) for g in explicit_groups)
    else:
        allowed_groups = None

    preference = cfg.get('bloom_model_preference')
    if preference and isinstance(preference, dict):
        matched_list = None
        for range_key, model_list in preference.items():
            try:
                levels = parse_bloom_range(range_key)
                if bloom in levels:
                    matched_list = model_list
                    break
            except (ValueError, IndexError):
                continue

        if matched_list and isinstance(matched_list, list):
            for pref_model in matched_list:
                spec = tiers.get(pref_model)
                if not isinstance(spec, dict):
                    continue
                mb = spec.get('max_bloom', 6)
                cg = spec.get('cost_group', 'unknown')
                if allowed_groups is not None and cg not in allowed_groups:
                    continue
                if isinstance(mb, int) and mb >= bloom:
                    print(pref_model)
                    sys.exit(0)

    candidates = []
    all_models = []
    for model, spec in tiers.items():
        if not isinstance(spec, dict):
            continue
        mb = spec.get('max_bloom', 6)
        cg = spec.get('cost_group', 'unknown')
        if allowed_groups is not None and cg not in allowed_groups:
            continue
        all_models.append((mb, cg, model))
        if isinstance(mb, int) and mb >= bloom:
            candidates.append((cost_priority.get(cg, 99), mb, model))

    if not all_models:
        sys.exit(0)

    if not candidates:
        best = max(all_models, key=lambda x: x[0])
        print(best[2])
    else:
        candidates.sort(key=lambda x: (x[1], x[0]))
        print(candidates[0][2])
except Exception:
    pass
" 2>/dev/null)

    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi

    # フォールバック: capability_tiers未定義時 L1-L3→sonnet, L4-L6→opus
    if [[ "$bloom_level" -le 3 ]]; then
        echo "sonnet"
    else
        echo "opus"
    fi
}

# find_agent_for_model(recommended_model)
# 指定モデルを使用するidle足軽を探す
# 引数: recommended_model — "sonnet" | "opus" 等
# 出力: agent_id (e.g., "ashigaru1") | "QUEUE" (全員ビジー)
# 戻り値: 0=成功, 1=引数不正
find_agent_for_model() {
    local recommended_model="$1"

    if [[ -z "$recommended_model" ]]; then
        return 1
    fi

    local settings="${CLI_ADAPTER_SETTINGS:-${CLI_ADAPTER_PROJECT_ROOT}/config/settings.yaml}"
    local pane_map="${CLI_ADAPTER_PROJECT_ROOT}/config/pane_role_map.yaml"

    # settings.yaml の cli.agents から候補を取得
    # 未定義の場合は pane_role_map.yaml からfallback
    local candidates
    candidates=$(python3 -c "
import yaml, sys

try:
    with open('${settings}') as f:
        cfg = yaml.safe_load(f) or {}
    cli_cfg = cfg.get('cli', {})
    agents = cli_cfg.get('agents', {})

    if agents:
        results = []
        for agent_id, spec in agents.items():
            if not agent_id.startswith('ashigaru'):
                continue
            if not isinstance(spec, dict):
                continue
            agent_model = spec.get('model', '')
            if agent_model == '${recommended_model}':
                results.append(agent_id)
        results.sort(key=lambda x: int(x.replace('ashigaru', '')) if x.replace('ashigaru', '').isdigit() else 99)
        print(' '.join(results))
        sys.exit(0)
except Exception:
    pass
" 2>/dev/null)

    # cli.agents未定義の場合: pane_role_map.yamlからashigaru一覧をfallback取得
    if [[ -z "$candidates" ]] && [[ -f "$pane_map" ]]; then
        candidates=$(grep 'ashigaru' "$pane_map" \
            | awk -F': ' '{print $2}' \
            | sort -t'u' -k2 -n \
            2>/dev/null | tr '\n' ' ')
    fi

    # agent_status.sh をsourceしてagent_is_busy_checkを利用
    local agent_status_lib="${CLI_ADAPTER_PROJECT_ROOT}/lib/agent_status.sh"
    if [[ -f "$agent_status_lib" ]]; then
        if ! declare -f agent_is_busy_check >/dev/null 2>&1; then
            # shellcheck disable=SC1090
            source "$agent_status_lib" 2>/dev/null
        fi
    fi

    local candidate
    for candidate in $candidates; do
        # tmux pane を @agent_id で逆引き（pane番号ハードコードなし）
        local pane_target
        pane_target=$(tmux list-panes -a \
            -F '#{session_name}:#{window_index}.#{pane_index} #{@agent_id}' 2>/dev/null \
            | awk -v agent="$candidate" '$2 == agent {print $1}' | head -1)

        if [[ -z "$pane_target" ]]; then
            # tmuxセッションなし（テスト環境等）→ 候補をそのまま返す
            echo "$candidate"
            return 0
        fi

        if declare -f agent_is_busy_check >/dev/null 2>&1; then
            local busy_rc
            agent_is_busy_check "$pane_target" 2>/dev/null
            busy_rc=$?
            # 0=busy, 1=idle, 2=not_found
            if [[ $busy_rc -eq 1 ]]; then
                echo "$candidate"
                return 0
            fi
        else
            # agent_is_busy_check 未定義 → フォールバック（最初の候補を返す）
            echo "$candidate"
            return 0
        fi
    done

    # フェーズ2: 完全一致が全員ビジー → 任意のidle足軽にフォールバック
    local all_agents
    all_agents=$(python3 -c "
import yaml
try:
    with open('${settings}') as f:
        cfg = yaml.safe_load(f) or {}
    agents = cfg.get('cli', {}).get('agents', {})
    results = [k for k in agents if k.startswith('ashigaru')]
    results.sort(key=lambda x: int(x.replace('ashigaru', '')) if x.replace('ashigaru', '').isdigit() else 99)
    print(' '.join(results))
except Exception:
    pass
" 2>/dev/null)

    # cli.agents未定義の場合はpane_role_map.yamlから全足軽
    if [[ -z "$all_agents" ]] && [[ -f "$pane_map" ]]; then
        all_agents=$(grep 'ashigaru' "$pane_map" \
            | awk -F': ' '{print $2}' \
            | sort -t'u' -k2 -n \
            2>/dev/null | tr '\n' ' ')
    fi

    local fallback
    for fallback in $all_agents; do
        if [[ " $candidates " == *" $fallback "* ]]; then
            continue
        fi

        local fb_pane
        fb_pane=$(tmux list-panes -a \
            -F '#{session_name}:#{window_index}.#{pane_index} #{@agent_id}' 2>/dev/null \
            | awk -v agent="$fallback" '$2 == agent {print $1}' | head -1)

        if [[ -z "$fb_pane" ]]; then
            echo "$fallback"
            return 0
        fi

        if declare -f agent_is_busy_check >/dev/null 2>&1; then
            agent_is_busy_check "$fb_pane" 2>/dev/null
            local fb_rc=$?
            if [[ $fb_rc -eq 1 ]]; then
                echo "$fallback"
                return 0
            fi
        fi
    done

    # 全足軽ビジー → キュー待ち
    echo "QUEUE"
    return 0
}
