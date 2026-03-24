#!/usr/bin/env python3
"""
dashboard_validate.py — ダッシュボード検証スクリプト
config/dashboard_config.yaml の output_path を検証対象とする。

使い方:
  uv run python scripts/dashboard_validate.py             # output_pathを検証
  uv run python scripts/dashboard_validate.py dashboard.md  # 指定ファイルを検証

終了コード:
  0: 問題なし
  1: Warning以上の問題あり
"""

import re
import sys
from pathlib import Path

import yaml

REQUIRED_SECTIONS = [
    "🚨 要対応",
    "📋 進行中",
    "📁 関連ファイル",
]

LINE_LIMIT = 200


def load_config(project_root: Path) -> dict:
    config_path = project_root / "config" / "dashboard_config.yaml"
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def validate(content: str, filepath: str) -> list[tuple[str, str]]:
    """検証を実行し、[(level, message), ...] を返す。levelは ERROR/WARNING/OK"""
    issues = []
    lines = content.splitlines()

    # 1. 必須セクション存在チェック
    for section in REQUIRED_SECTIONS:
        if not any(section in line for line in lines):
            issues.append(("ERROR", f"必須セクション「{section}」が存在しません"))

    # 2. 🚨要対応に「✅完了」行が残っていないか
    in_action_section = False
    for line in lines:
        if "🚨" in line and "要対応" in line:
            in_action_section = True
        elif line.startswith("## ") and "🚨" not in line:
            in_action_section = False
        if in_action_section and "✅" in line and "|" in line:
            # テーブル行に✅がある = 完了行が残存している
            issues.append(("WARNING", f"🚨要対応セクションに完了行(✅)が残存しています: {line.strip()[:80]}"))

    # 3. 200行超え警告
    line_count = len(lines)
    if line_count > LINE_LIMIT:
        issues.append(("WARNING", f"行数が上限を超えています: {line_count}行 (上限: {LINE_LIMIT}行)"))

    return issues


def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    config = load_config(project_root)

    if len(sys.argv) > 1:
        target = Path(sys.argv[1])
        if not target.is_absolute():
            target = project_root / target
    else:
        target = project_root / config["output_path"]

    if not target.exists():
        print(f"ERROR: ファイルが存在しません: {target}", file=sys.stderr)
        sys.exit(1)

    content = target.read_text(encoding="utf-8")
    issues = validate(content, str(target))

    print(f"検証対象: {target}")
    print(f"行数: {len(content.splitlines())}")

    if not issues:
        print("✅ 問題なし")
        sys.exit(0)

    has_error = False
    for level, msg in issues:
        icon = "❌" if level == "ERROR" else "⚠️"
        print(f"{icon} [{level}] {msg}")
        if level == "ERROR":
            has_error = True

    if has_error or issues:
        sys.exit(1)


if __name__ == "__main__":
    main()
