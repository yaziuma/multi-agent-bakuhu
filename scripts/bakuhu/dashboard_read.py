#!/usr/bin/env python3
"""
dashboard_read.py — ダッシュボード読み込み・生成スクリプト
YAMLデータソースからMarkdownダッシュボードを生成する。

使い方:
  uv run python scripts/dashboard_read.py                         # 全体生成→output_pathに保存
  uv run python scripts/dashboard_read.py --stdout                # 標準出力
  uv run python scripts/dashboard_read.py --section action        # 🚨要対応のみ
  uv run python scripts/dashboard_read.py --section progress      # 📋進行中のみ
  uv run python scripts/dashboard_read.py --section senka         # ✅戦果のみ
  uv run python scripts/dashboard_read.py --section agents        # エージェント状態（tmux不要版）
"""

import argparse
import glob
import os
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import yaml


def load_config(project_root: Path) -> dict:
    config_path = project_root / "config" / "dashboard_config.yaml"
    with open(config_path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_state(project_root: Path, config: dict) -> dict:
    state_path = project_root / config["state_path"]
    if not state_path.exists():
        return {"action_required": [], "projects": [], "archives": []}
    with open(state_path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def load_task_yamls(project_root: Path, config: dict) -> list[dict]:
    tasks_dir = project_root / config["tasks_dir"]
    tasks = []
    for path in sorted(tasks_dir.glob("ashigaru*.yaml")):
        try:
            with open(path, encoding="utf-8") as f:
                data = yaml.safe_load(f)
                if data:
                    tasks.append(data)
        except Exception:
            pass
    return tasks


def load_today_reports(project_root: Path, config: dict) -> list[dict]:
    reports_dir = project_root / config["reports_dir"]
    today = datetime.now().strftime("%Y-%m-%d")
    reports = []
    for path in sorted(reports_dir.glob("*.yaml")):
        try:
            with open(path, encoding="utf-8") as f:
                data = yaml.safe_load(f)
                if not data:
                    continue
                # タイムスタンプが今日のものを抽出
                ts = str(data.get("timestamp", data.get("completed_at", "")))
                if today in ts:
                    reports.append(data)
        except Exception:
            pass
    return reports


def build_action_section(state: dict) -> str:
    items = state.get("action_required", [])
    if not items:
        return "## 🚨 要対応（殿のご判断待ち）\n\n（なし）\n"

    lines = ["## 🚨 要対応（殿のご判断待ち）", ""]
    lines.append("| # | cmd_id | PJ | 種別 | 内容 |")
    lines.append("|---|--------|-----|------|------|")
    for i, item in enumerate(items, 1):
        cmd_id = item.get("cmd_id") or "—"
        project = item.get("project", "")
        type_ = item.get("type", "")
        content = item.get("content", "").replace("\n", " ")
        lines.append(f"| {i} | {cmd_id} | {project} | {type_} | {content} |")
    lines.append("")
    return "\n".join(lines)


def build_progress_section(tasks: list[dict]) -> str:
    active = [
        t for t in tasks
        if t.get("status") in ("assigned", "in_progress")
    ]
    lines = ["## 📋 進行中", ""]
    if not active:
        lines.append("（なし）")
        lines.append("")
        return "\n".join(lines)

    lines.append("| cmd_id | PJ | 足軽 | 内容 | 状態 |")
    lines.append("|--------|-----|------|------|------|")
    for t in active:
        cmd_id = t.get("cmd_id", "—")
        project = t.get("project", "—")
        assigned_to = t.get("assigned_to", "—")
        title = t.get("title", t.get("task_id", "—"))
        status = t.get("status", "—")
        lines.append(f"| {cmd_id} | {project} | {assigned_to} | {title} | {status} |")
    lines.append("")
    return "\n".join(lines)


def build_senka_section(reports: list[dict]) -> str:
    lines = ["## ✅ 本日の戦果", ""]
    if not reports:
        lines.append("| 時刻 | cmd_id | PJ | 内容 |")
        lines.append("|------|--------|-----|------|")
        lines.append("（本日分なし）")
        lines.append("")
        return "\n".join(lines)

    lines.append("| 時刻 | cmd_id | PJ | 内容 |")
    lines.append("|------|--------|-----|------|")
    for r in sorted(reports, key=lambda x: str(x.get("timestamp", x.get("completed_at", ""))), reverse=True):
        ts = str(r.get("timestamp", r.get("completed_at", "")))
        time_str = ts[11:16] if len(ts) >= 16 else ts
        cmd_id = r.get("cmd_id", r.get("task_id", "—"))
        project = r.get("project", "—")
        content = r.get("summary", r.get("content", r.get("title", "—"))).replace("\n", " ")[:80]
        lines.append(f"| {time_str} | {cmd_id} | {project} | {content} |")
    lines.append("")
    return "\n".join(lines)


def build_related_files_section(state: dict) -> str:
    lines = ["## 📁 関連ファイル", "", "### アーカイブ", ""]
    for arch in state.get("archives", []):
        path = arch.get("path", "")
        desc = arch.get("description", "")
        lines.append(f"- **{path}** — {desc}")
    lines.append("")
    lines.append("### プロジェクト")
    lines.append("")
    for pj in state.get("projects", []):
        name = pj.get("name", "")
        path = pj.get("path", "")
        url = pj.get("url", "")
        if url:
            lines.append(f"- {name}: `{path}` ({url})")
        else:
            lines.append(f"- {name}: `{path}`")
    lines.append("")
    return "\n".join(lines)


def build_summary(tasks: list[dict], reports: list[dict], state: dict, project_root: Path, config: dict) -> str:
    lines = ["=== 戦況要約 ==="]

    # 要対応
    action_items = state.get("action_required", [])
    action_count = len(action_items)
    type_counts = Counter(item.get("type", "不明") for item in action_items)
    type_summary = ", ".join(f"{t}:{c}" for t, c in type_counts.most_common())
    lines.append(f"🚨 要対応: {action_count}件" + (f"（{type_summary}）" if type_summary else ""))

    # 進行中
    active = [t for t in tasks if t.get("status") in ("assigned", "in_progress")]
    if active:
        parts = [f"{t.get('assigned_to','?')}={t.get('task_id','?')}({t.get('project','?')})" for t in active]
        lines.append(f"📋 進行中: {', '.join(parts)}")
    else:
        lines.append("📋 進行中: なし")

    # 本日の戦果
    lines.append(f"✅ 本日の戦果: {len(reports)}件")
    lines.append("---")

    # 種別内訳
    if type_counts:
        lines.append("🚨 種別内訳:")
        for type_name, count in type_counts.most_common():
            cmd_ids = [str(item.get("cmd_id", "")) for item in action_items if item.get("type") == type_name]
            if len(cmd_ids) <= 3:
                cmd_str = f" ({', '.join(cmd_ids)})" if cmd_ids else ""
            else:
                cmd_str = f" ({', '.join(cmd_ids[:3])}, ...)"
            lines.append(f"  {type_name}: {count}件{cmd_str}")
        lines.append("---")

    # 足軽状態
    tasks_dir = project_root / config["tasks_dir"]
    agent_statuses = []
    for i in range(1, 9):
        path = tasks_dir / f"ashigaru{i}.yaml"
        if path.exists():
            try:
                with open(path, encoding="utf-8") as f:
                    data = yaml.safe_load(f)
                status = data.get("status", "idle") if data else "idle"
                agent_statuses.append(f"ashigaru{i}={status}")
            except Exception:
                agent_statuses.append(f"ashigaru{i}=unknown")
    if agent_statuses:
        lines.append(f"足軽状態: {', '.join(agent_statuses)}")

    # 軍師状態
    extra = []
    gunshi_path = tasks_dir / "gunshi.yaml"
    if gunshi_path.exists():
        try:
            with open(gunshi_path, encoding="utf-8") as f:
                data = yaml.safe_load(f)
            status = data.get("status", "idle") if data else "idle"
            extra.append(f"軍師: {status}")
        except Exception:
            extra.append("軍師: unknown")
    if extra:
        lines.append(" | ".join(extra))

    return "\n".join(lines)


def build_full_dashboard(tasks: list[dict], reports: list[dict], state: dict) -> str:
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    header = f"""# 戦況報告書（Dashboard）

> **最終更新**: {now}
> **更新者**: dashboard_read.py（自動生成）
> **家老コンテキスト**: 🟢 未測定

---

"""
    sections = [
        header,
        build_action_section(state) + "\n---\n\n",
        build_progress_section(tasks) + "\n---\n\n",
        build_senka_section(reports) + "\n---\n\n",
        build_related_files_section(state),
    ]
    return "".join(sections)


def main():
    parser = argparse.ArgumentParser(description="ダッシュボード生成スクリプト")
    parser.add_argument(
        "--section",
        choices=["action", "progress", "senka", "agents"],
        help="特定セクションのみ出力",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="標準出力に出力（ファイルに書き込まない）",
    )
    parser.add_argument(
        "--format",
        choices=["summary"],
        dest="format",
        help="出力フォーマット（summary: 要約モード 15-20行）",
    )
    args = parser.parse_args()

    # プロジェクトルートを特定（このスクリプトの親ディレクトリ）
    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    config = load_config(project_root)
    state = load_state(project_root, config)
    tasks = load_task_yamls(project_root, config)
    reports = load_today_reports(project_root, config)

    if args.format == "summary":
        output = build_summary(tasks, reports, state, project_root, config)
        print(output)
        return

    if args.section == "action":
        output = build_action_section(state)
    elif args.section == "progress":
        output = build_progress_section(tasks)
    elif args.section == "senka":
        output = build_senka_section(reports)
    elif args.section == "agents":
        output = "## エージェント状態\n\n（tmuxコマンドで確認: tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{@agent_id}'）\n"
    else:
        output = build_full_dashboard(tasks, reports, state)

    if args.stdout or args.section:
        print(output)
    else:
        output_path = project_root / config["output_path"]
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"生成完了: {output_path}", file=sys.stderr)
        print(f"  要対応: {len(state.get('action_required', []))}件", file=sys.stderr)
        print(f"  進行中: {len([t for t in tasks if t.get('status') in ('assigned', 'in_progress')])}件", file=sys.stderr)
        print(f"  本日の戦果: {len(reports)}件", file=sys.stderr)


if __name__ == "__main__":
    main()
