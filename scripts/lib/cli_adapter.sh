#!/bin/bash
# scripts/lib/cli_adapter.sh — 後方互換wrapperシム
# cmd_490で仮実装。cmd_491で lib/cli_adapter.sh に本家準拠の完全版を移植済み。
# 本ファイルは後方互換のためwrapperとして残す。

# lib/cli_adapter.sh の完全版をsource
_SCRIPTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_ROOT="$(cd "${_SCRIPTS_LIB_DIR}/../.." && pwd)"
if [[ -f "${_PROJECT_ROOT}/lib/cli_adapter.sh" ]]; then
    # shellcheck disable=SC1090
    source "${_PROJECT_ROOT}/lib/cli_adapter.sh"
fi
