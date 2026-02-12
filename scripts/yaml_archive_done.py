#!/usr/bin/env python3
"""
Archive done/completed commands from shogun_to_karo.yaml.

This script:
1. Reads queue/shogun_to_karo.yaml
2. Filters commands by status (done/completed)
3. Writes archived commands to logs/archive/YYYY-MM-DD/shogun_to_karo_done_HHMMSS.yaml
4. Overwrites original file with active commands only
"""

from datetime import datetime
from pathlib import Path

import yaml


def archive_done_commands():
    """Archive done/completed commands from shogun_to_karo.yaml."""
    # File paths
    input_file = Path("queue/shogun_to_karo.yaml")
    if not input_file.exists():
        print(f"Error: {input_file} not found")
        return

    # Read YAML
    with open(input_file) as f:
        data = yaml.safe_load(f)

    if not data or "commands" not in data:
        print("Error: Invalid YAML structure (missing 'commands' key)")
        return

    commands = data.get("commands", [])

    # Filter by status
    archive_list = []
    active_list = []

    for cmd in commands:
        status = cmd.get("status", "").lower()
        if status in ("done", "completed"):
            archive_list.append(cmd)
        else:
            active_list.append(cmd)

    # No archived commands
    if not archive_list:
        print("archived: 0 commands (nothing to archive)")
        print(f"remaining: {len(active_list)} commands (active)")
        return

    # Create archive directory
    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%H%M%S")
    archive_dir = Path(f"logs/archive/{date_str}")
    archive_dir.mkdir(parents=True, exist_ok=True)

    archive_file = archive_dir / f"shogun_to_karo_done_{time_str}.yaml"

    # Write archive file
    archive_data = {
        "__comment": f"Archived: {now.strftime('%Y-%m-%dT%H:%M:%S')}",
        "__source": "queue/shogun_to_karo.yaml",
        "commands": archive_list,
    }
    with open(archive_file, "w") as f:
        yaml.dump(
            archive_data, f, allow_unicode=True, default_flow_style=False, sort_keys=False
        )

    # Overwrite original file with active commands
    active_data = {"commands": active_list}
    with open(input_file, "w") as f:
        yaml.dump(
            active_data, f, allow_unicode=True, default_flow_style=False, sort_keys=False
        )

    # Print results
    print(f"archived: {len(archive_list)} commands → {archive_file}")
    print(f"remaining: {len(active_list)} commands (active)")


if __name__ == "__main__":
    archive_done_commands()
