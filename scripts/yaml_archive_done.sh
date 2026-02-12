#!/bin/bash
# Archive done/completed commands from shogun_to_karo.yaml
# Usage: bash scripts/yaml_archive_done.sh

set -e

cd "$(dirname "$0")/.."
python3 scripts/yaml_archive_done.py
