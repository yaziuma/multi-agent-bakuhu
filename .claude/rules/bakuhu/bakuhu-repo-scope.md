# Bakuhu Repository Scope Rule (Lord's Absolute Order)

The bakuhu repository (`multi-agent-bakuhu/`) contains ONLY the multi-agent system itself.

## What belongs in bakuhu

- Agent instructions (`instructions/`)
- Agent scripts (`scripts/`)
- Queue system (`queue/`)
- Agent configuration (`.claude/`, `config/`)
- Context files (`context/`)
- Skills (`skills/`)
- Logs (`logs/`)

## What does NOT belong in bakuhu

- Web applications (FastAPI, Flask, etc.)
- Static sites (HTML/CSS/JS)
- Independent tools or utilities
- Any project that can run independently

These must be placed as independent projects under `/home/quieter/projects/`.

## Past violations (never repeat)

| Item | Was in | Moved to |
|------|--------|----------|
| queue-viewer | `multi-agent-bakuhu/queue-viewer/` | `/home/quieter/projects/queue-viewer/` (cmd_265) |
| portal | `multi-agent-bakuhu/portal/` | `/home/quieter/projects/portal/` (cmd_266) |

## Enforcement

- Before creating any new directory in bakuhu, check: "Is this an agent system component?"
- If NO, create it under `/home/quieter/projects/` instead
- Violations will be immediately corrected and the responsible agent reprimanded
