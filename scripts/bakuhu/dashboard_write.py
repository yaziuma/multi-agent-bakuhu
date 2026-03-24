#!/usr/bin/env python3
"""
dashboard_write.py — ダッシュボード書き込みスクリプト
queue/dashboard_state.yaml を操作するCLI。dashboard.mdは直接触らない。

使い方:
  uv run python scripts/dashboard_write.py add-action --cmd cmd_123 --pj bakuhu --type "殿判断待ち" --content "push許可待ち"
  uv run python scripts/dashboard_write.py remove-action --cmd cmd_123
  uv run python scripts/dashboard_write.py list-action
  uv run python scripts/dashboard_write.py add-senka --cmd cmd_123 --pj bakuhu --content "HTMLファイル表示実装完了"
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path

import yaml


def load_config(project_root: Path) -> dict:
    config_path = project_root / "config" / "dashboard_config.yaml"
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_state(state_path: Path) -> dict:
    if not state_path.exists():
        return {"action_required": [], "projects": [], "archives": []}
    with open(state_path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def save_state(state_path: Path, state: dict) -> None:
    with open(state_path, "w", encoding="utf-8") as f:
        yaml.dump(state, f, allow_unicode=True, default_flow_style=False, sort_keys=False)


def resolve_project(project_root: Path, config: dict, cmd_id: str) -> str | None:
    """cmd_idからプロジェクト名を自動解決する。見つからなければNoneを返す。"""
    # 1. queue/commands/{cmd_id}.yaml の project フィールド
    commands_dir = project_root / config.get("commands_dir", "queue/commands")
    cmd_file = commands_dir / f"{cmd_id}.yaml"
    if cmd_file.exists():
        try:
            with open(cmd_file, encoding="utf-8") as f:
                data = yaml.safe_load(f)
            if data and data.get("project"):
                return data["project"]
        except Exception:
            pass

    # 2. queue/tasks/ashigaru*.yaml の cmd_id マッチ → project フィールド
    tasks_dir = project_root / config.get("tasks_dir", "queue/tasks")
    for path in sorted(tasks_dir.glob("ashigaru*.yaml")):
        try:
            with open(path, encoding="utf-8") as f:
                data = yaml.safe_load(f)
            if data and data.get("cmd_id") == cmd_id and data.get("project"):
                return data["project"]
        except Exception:
            pass

    return None


def generate_id(state: dict) -> str:
    items = state.get("action_required", [])
    if not items:
        return "ar_001"
    existing_nums = []
    for item in items:
        id_ = item.get("id", "")
        if id_.startswith("ar_"):
            try:
                existing_nums.append(int(id_[3:]))
            except ValueError:
                pass
    next_num = max(existing_nums, default=0) + 1
    return f"ar_{next_num:03d}"


def cmd_add_action(state_path: Path, state: dict, args) -> None:
    today = datetime.now().strftime("%Y-%m-%d")
    new_id = generate_id(state)
    new_item = {
        "id": new_id,
        "cmd_id": args.cmd,
        "project": args.pj,
        "type": args.type,
        "content": args.content,
        "added": today,
    }
    state.setdefault("action_required", []).append(new_item)
    save_state(state_path, state)
    print(f"追加完了: {new_id} ({args.cmd} / {args.pj})")


def cmd_remove_action(state_path: Path, state: dict, args) -> None:
    items = state.get("action_required", [])
    before = len(items)
    state["action_required"] = [
        item for item in items
        if item.get("cmd_id") != args.cmd
    ]
    after = len(state["action_required"])
    if before == after:
        print(f"警告: cmd_id={args.cmd} の要対応が見つかりませんでした", file=sys.stderr)
        sys.exit(1)
    save_state(state_path, state)
    print(f"削除完了: cmd_id={args.cmd} ({before - after}件削除)")


def cmd_list_action(state: dict) -> None:
    items = state.get("action_required", [])
    if not items:
        print("（要対応なし）")
        return
    print(f"要対応: {len(items)}件")
    print(f"{'#':<4} {'id':<8} {'cmd_id':<15} {'project':<25} {'type':<25} 内容")
    print("-" * 100)
    for i, item in enumerate(items, 1):
        id_ = item.get("id", "—")
        cmd_id = str(item.get("cmd_id") or "—")
        project = item.get("project", "—")[:24]
        type_ = item.get("type", "—")[:24]
        content = item.get("content", "—")[:40].replace("\n", " ")
        print(f"{i:<4} {id_:<8} {cmd_id:<15} {project:<25} {type_:<25} {content}")


def cmd_add_senka(state_path: Path, state: dict, args) -> None:
    today = datetime.now().strftime("%Y-%m-%d")
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    senka_list = state.setdefault("senka", [])
    senka_list.append({
        "cmd_id": args.cmd,
        "project": args.pj,
        "content": args.content,
        "date": today,
        "timestamp": now,
    })
    save_state(state_path, state)
    print(f"戦果追記完了: cmd_id={args.cmd} ({args.pj}): {args.content[:50]}")


def main():
    parser = argparse.ArgumentParser(description="ダッシュボード書き込みスクリプト")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # add-action
    p_add = subparsers.add_parser("add-action", help="🚨要対応に追加")
    p_add.add_argument("--cmd", required=True, help="cmd_id (例: cmd_123)")
    p_add.add_argument("--pj", default=None, help="プロジェクト名（省略時はcmd/task YAMLから自動解決）")
    p_add.add_argument("--type", required=True, dest="type", help="種別 (例: 殿判断待ち)")
    p_add.add_argument("--content", required=True, help="内容")

    # remove-action
    p_rm = subparsers.add_parser("remove-action", help="🚨要対応から削除（完了時）")
    p_rm.add_argument("--cmd", required=True, help="cmd_id")

    # list-action
    subparsers.add_parser("list-action", help="🚨要対応一覧表示")

    # add-senka
    p_senka = subparsers.add_parser("add-senka", help="戦果を記録")
    p_senka.add_argument("--cmd", required=True, help="cmd_id")
    p_senka.add_argument("--pj", default=None, help="プロジェクト名（省略時はcmd/task YAMLから自動解決）")
    p_senka.add_argument("--content", required=True, help="内容")

    args = parser.parse_args()

    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    config = load_config(project_root)
    state_path = project_root / config["state_path"]
    state = load_state(state_path)

    if args.command in ("add-action", "add-senka") and args.pj is None:
        resolved = resolve_project(project_root, config, args.cmd)
        if resolved:
            print(f"--pj 自動解決: {resolved} (cmd_id={args.cmd})", file=sys.stderr)
            args.pj = resolved
        else:
            print(
                f"エラー: --pj が指定されておらず、cmd_id={args.cmd} からプロジェクトを自動解決できませんでした。"
                " --pj を明示的に指定してください。",
                file=sys.stderr,
            )
            sys.exit(1)

    if args.command == "add-action":
        cmd_add_action(state_path, state, args)
    elif args.command == "remove-action":
        cmd_remove_action(state_path, state, args)
    elif args.command == "list-action":
        cmd_list_action(state)
    elif args.command == "add-senka":
        cmd_add_senka(state_path, state, args)


if __name__ == "__main__":
    main()
