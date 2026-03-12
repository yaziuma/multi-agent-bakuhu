#!/bin/bash
# cli_adapter.sh - CLIアダプタ共通関数
# bloom_routingのモデル選択・エージェント検索に使用

# get_recommended_model(bloom_level)
# bloom_levelに基づく推奨モデルを返す
# L1-L3 → sonnet, L4-L6 → opus
get_recommended_model() {
    local bloom_level="$1"
    local level_num="${bloom_level#L}"
    if [[ "$level_num" -le 3 ]]; then
        echo "sonnet"
    else
        echo "opus"
    fi
}

# find_agent_for_model(model_name)
# 指定モデルが使用可能な空きエージェントを返す
# pane_role_map.yaml から足軽一覧を取得し、idle状態のものを探す
find_agent_for_model() {
    local model_name="$1"
    local project_root
    project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local pane_map="${project_root}/config/pane_role_map.yaml"

    if [[ ! -f "$pane_map" ]]; then
        echo ""
        return 1
    fi

    # pane_role_map.yamlから足軽一覧を取得
    grep 'ashigaru' "$pane_map" | while IFS=': ' read -r pane role; do
        local agent_model
        agent_model=$(get_agent_model "$role" 2>/dev/null || echo "")
        if [[ "$agent_model" == "$model_name" ]]; then
            echo "$role"
            return 0
        fi
    done
}
