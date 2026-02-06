<div align="center">

# multi-agent-bakuhu

**Command your AI army like a feudal warlord.**

Run multiple Claude Code agents in parallel — orchestrated through a samurai-inspired hierarchy with zero coordination overhead.

[![GitHub Stars](https://img.shields.io/github/stars/yaziuma/multi-agent-bakuhu?style=social)](https://github.com/yaziuma/multi-agent-bakuhu)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Built_for-Claude_Code-blueviolet)](https://code.claude.com)
[![Shell](https://img.shields.io/badge/Shell%2FBash-100%25-green)]()

[English](README.md) | [日本語](README_ja.md)

</div>

---

Give a single command. The **Shogun** (general) delegates to the **Karo** (steward), who distributes work across **Ashigaru** (foot soldiers) — all running as independent Claude Code processes in tmux. **Denrei** (messengers) summon external specialists like **Shinobi** (Gemini) and **Gunshi** (Codex). Communication flows through YAML files and tmux `send-keys`, meaning **zero extra API calls** for agent coordination.

> Forked from [yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun). Extensively redesigned with external agent integration, context health management, archival systems, and a deeper feudal hierarchy.

## Why Bakuhu?

Most multi-agent frameworks burn API tokens on coordination. Bakuhu doesn't.

| | Claude Code `Task` tool | LangGraph | CrewAI | **multi-agent-bakuhu** |
|---|---|---|---|---|
| **Architecture** | Subagents inside one process | Graph-based state machine | Role-based agents | Feudal hierarchy via tmux |
| **Parallelism** | Sequential (one at a time) | Parallel nodes (v0.2+) | Limited | **N independent agents** |
| **Coordination cost** | API calls per Task | API + infra (Postgres/Redis) | API + CrewAI platform | **Zero** (YAML + tmux) |
| **Observability** | Claude logs only | LangSmith integration | OpenTelemetry | **Live tmux panes** + dashboard |
| **Skill discovery** | None | None | None | **Bottom-up auto-proposal** |
| **External agents** | None | Custom integrations | Custom integrations | **Gemini + Codex via messengers** |
| **Setup** | Built into Claude Code | Heavy (infra required) | pip install | Shell scripts |

### What makes this different

**Zero coordination overhead** — Agents talk through YAML files on disk. The only API calls are for actual work, not orchestration.

**Full transparency** — Every agent runs in a visible tmux pane. Every instruction, report, and decision is a plain YAML file you can read, diff, and version-control. No black boxes.

**Battle-tested hierarchy** — The Shogun → Karo → Ashigaru chain of command prevents conflicts by design: clear ownership, dedicated files per agent, event-driven communication, no polling.

**Multi-model orchestration** — Claude (Opus/Sonnet/Haiku), Gemini, and Codex work together. Each model is deployed where its strengths matter most.

---

## Architecture

```
        You (上様 / The Lord)
             │
             ▼  Give orders
      ┌─────────────┐
      │   SHOGUN    │  Receives your command, plans strategy
      │    (将軍)    │  Session: shogun
      └──────┬──────┘
             │  YAML + send-keys
      ┌──────▼──────┐
      │    KARO     │  Breaks tasks down, assigns to workers
      │    (家老)    │  Session: multiagent, pane 0
      └──────┬──────┘
             │  YAML + send-keys
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌───┬───┬───┐    ┌───┬───┐         ┌────────┐   ┌────────┐
│ 1 │ 2 │ 3 │    │D1 │D2 │ ──────→ │ Shinobi│   │ Gunshi │
└───┴───┴───┘    └───┴───┘         │(Gemini)│   │(Codex) │
   ASHIGARU        DENREI           └────────┘   └────────┘
  Foot soldiers   Messengers        External Agents
```

### Agent roles

| Agent | Role | Model | Count |
|-------|------|-------|-------|
| **Shogun (将軍)** | Commander — receives your orders, delegates to Karo | Opus | 1 |
| **Karo (家老)** | Steward — breaks tasks down, assigns to Ashigaru, maintains dashboard | Opus | 1 (+1 standby) |
| **Ashigaru (足軽)** | Foot soldiers — execute tasks in parallel | Sonnet/Opus | Configurable (default: 3) |
| **Denrei (伝令)** | Messengers — summon and relay with external agents | Haiku | 2 |
| **Shinobi (忍び)** | Intelligence — research, web search, large document analysis | Gemini | External |
| **Gunshi (軍師)** | Strategist — deep reasoning, code review, design decisions | Codex | External |

### Communication protocol

- **Downward** (orders): Write YAML → wake target with `tmux send-keys`
- **Upward** (reports): Write YAML only (no send-keys to avoid interrupting your input)
- **External agents**: Always summoned via Denrei (never directly)
- **Polling**: Forbidden. Event-driven only. Your API bill stays predictable.

### Context persistence (4 layers)

| Layer | What | Survives |
|-------|------|----------|
| Memory MCP | Preferences, rules, cross-project knowledge | Everything |
| Project files | `config/projects.yaml`, `context/*.md` | Everything |
| YAML Queue | Tasks, reports (source of truth) | Everything |
| Session | `CLAUDE.md`, instructions | `/clear` wipes it |

After `/clear`, an agent recovers in **~2,000 tokens** by reading Memory MCP + its task YAML. No expensive re-prompting.

---

## External Agents

The Shogun can summon external specialists **via Denrei (messengers)** for tasks that require capabilities beyond Claude Code:

| Agent | Tool | Role | Strengths |
|-------|------|------|-----------|
| **Shinobi (忍び)** | Gemini CLI | Intelligence & Research | 1M token context, Web search, PDF/video analysis |
| **Gunshi (軍師)** | Codex CLI | Strategic Advisor | Deep reasoning, Design decisions, Code review |

**Key rules:**
- Shogun/Karo summon external agents **only via Denrei** (forbidden action F006 if done directly)
- Denrei handle the blocking API calls, keeping the command chain responsive
- Ashigaru can summon with explicit permission (`shinobi_allowed: true` in task YAML)

---

## Bottom-Up Skill Discovery

As Ashigaru execute tasks, they **automatically identify reusable patterns** and propose them as skill candidates. The Karo aggregates these proposals in `dashboard.md`, and you — the Lord — decide what gets promoted to a permanent skill.

```
Ashigaru finishes a task
    ↓
Notices: "I've done this pattern 3 times across different projects"
    ↓
Reports in YAML:  skill_candidate:
                     found: true
                     name: "api-endpoint-scaffold"
                     reason: "Same REST scaffold pattern used in 3 projects"
    ↓
Appears in dashboard.md → You approve → Skill created
    ↓
Any agent can now invoke the skill
```

Skills grow organically from real work — not from a predefined template library. Your skill set becomes a reflection of **your** workflow.

---

## Context Health Management

Long-running agents accumulate context, driving up API costs. Bakuhu manages this with built-in strategies:

| Agent | Strategy | Rationale |
|-------|----------|-----------|
| **Shogun** | `/compact` preferred | Context preservation is critical |
| **Karo** | Mixed: `/compact` 3× → `/clear` 1× | Balance context retention and cost (30% savings) |
| **Ashigaru** | `/clear` after each task | Clean slate per task, minimal recovery cost |
| **Denrei** | `/clear` after each task | Stateless by design |

A **standby Karo** (hot spare) can take over when the primary Karo needs `/clear`, ensuring continuity of operations.

### Archival system

Completed commands, old reports, and resolved dashboard sections are archived (never deleted) to `logs/archive/YYYY-MM-DD/`. The `scripts/extract-section.sh` tool enables selective reading of dashboard sections, reducing token consumption during compaction recovery.

---

## Battle Formations

Agents can be deployed in different **formations** (陣形 / *jindate*) depending on the task:

| Formation | Ashigaru | Best for |
|-----------|----------|----------|
| **Normal** (default) | Sonnet | Everyday tasks — cost-efficient |
| **Battle** (`-k` flag) | Opus | Critical tasks — maximum capability |

```bash
./shutsujin_departure.sh          # Normal formation
./shutsujin_departure.sh -k       # Battle formation (all Opus)
```

The Karo can also promote individual Ashigaru mid-session with `/model opus` when a specific task demands it.

---

## Quick Start

### Windows (WSL2)

```bash
# 1. Clone
git clone https://github.com/yaziuma/multi-agent-bakuhu.git C:\tools\multi-agent-bakuhu

# 2. Run installer (right-click → Run as Administrator)
#    → install.bat handles WSL2 + Ubuntu setup automatically

# 3. In Ubuntu terminal:
cd /mnt/c/tools/multi-agent-bakuhu
./first_setup.sh          # One-time: installs tmux, Node.js, Claude Code CLI
./shutsujin_departure.sh  # Deploy your army
```

### Linux / macOS

```bash
# 1. Clone
git clone https://github.com/yaziuma/multi-agent-bakuhu.git ~/multi-agent-bakuhu
cd ~/multi-agent-bakuhu && chmod +x *.sh

# 2. Setup + Deploy
./first_setup.sh          # One-time: installs dependencies
./shutsujin_departure.sh  # Deploy your army
```

### Daily startup

```bash
cd /path/to/multi-agent-bakuhu
./shutsujin_departure.sh
tmux attach-session -t shogun   # Connect and give orders
```

<details>
<summary><b>Convenient aliases</b> (added by first_setup.sh)</summary>

```bash
alias csst='cd /mnt/c/tools/multi-agent-bakuhu && ./shutsujin_departure.sh'
alias css='tmux attach-session -t shogun'
alias csm='tmux attach-session -t multiagent'
```

</details>

---

## How It Works

### 1. Give an order

```
You: "Research the top 5 MCP servers and create a comparison table"
```

### 2. Shogun delegates instantly

The Shogun writes the task to `queue/shogun_to_karo.yaml` and wakes the Karo. Control returns to you immediately — no waiting.

### 3. Karo distributes

The Karo breaks the task into subtasks and assigns each to an Ashigaru:

| Worker | Assignment |
|--------|-----------|
| Ashigaru 1 | Research Notion MCP |
| Ashigaru 2 | Research GitHub MCP |
| Ashigaru 3 | Research Playwright MCP |

Need deeper research? The Karo dispatches a Denrei to summon the Shinobi (Gemini) for web search and large-document analysis.

### 4. Parallel execution

All Ashigaru work simultaneously. You can watch them in real time via tmux panes.

### 5. Results in dashboard

Open `dashboard.md` to see aggregated results, skill candidates, and blockers — all maintained by the Karo.

---

## Real-World Use Cases

This system manages **all white-collar tasks**, not just code. Projects can live anywhere on your filesystem.

```yaml
# config/projects.yaml
projects:
  - id: client_x
    name: "Client X Consulting"
    path: "/mnt/c/Consulting/client_x"
    status: active
```

**Research sprints** — Multiple agents research different topics in parallel, results compiled in minutes.

**Multi-project management** — Switch between client projects without losing context. Memory MCP preserves preferences across sessions.

**Document generation** — Technical writing, test case reviews, comparison tables — distributed across agents and merged.

**Multi-model research** — Combine Claude's coding ability with Gemini's 1M-token context and Codex's deep reasoning for comprehensive analysis.

---

## Configuration

### `config/settings.yaml`

```yaml
# Agent counts
ashigaru_count: 3          # 1-8 foot soldiers

# Language
language: ja               # ja = Japanese only, en = Japanese + English

# Denrei (messengers)
denrei:
  max_count: 2
  model: haiku

# Standby Karo (hot spare)
karo_standby:
  enabled: true
  model: opus

# Gunshi (Codex strategist)
gunshi:
  model: gpt-5.2-codex
  sandbox: read-only
```

### Model assignment

| Agent | Default Model | Thinking |
|-------|--------------|----------|
| Shogun | Opus | Disabled (delegation doesn't need deep reasoning) |
| Karo | Opus | Enabled |
| Ashigaru | Sonnet / Opus | Enabled |
| Denrei 1–2 | Haiku | Disabled |

### MCP servers

```bash
# Memory (auto-configured by first_setup.sh)
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory

# Notion
claude mcp add notion -e NOTION_TOKEN=your_token -- npx -y @notionhq/notion-mcp-server

# GitHub
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat -- npx -y @modelcontextprotocol/server-github

# Playwright (browser automation)
claude mcp add playwright -- npx @playwright/mcp@latest

# Sequential Thinking
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

### Screenshot integration

```yaml
# config/settings.yaml
screenshot:
  path: "/mnt/c/Users/YourName/Pictures/Screenshots"
```

Tell the Shogun "check the latest screenshot" and it reads your screen captures for visual context.

---

## File Structure

```
multi-agent-bakuhu/
├── install.bat                # Windows first-time setup
├── first_setup.sh             # Linux/Mac first-time setup
├── shutsujin_departure.sh     # Daily deployment script
│
├── instructions/              # Agent behavior definitions
│   ├── shogun.md
│   ├── karo.md
│   ├── ashigaru.md
│   ├── denrei.md              # Messenger agents
│   ├── shinobi.md             # Gemini integration
│   └── gunshi.md              # Codex integration
│
├── config/
│   ├── settings.yaml          # Language, model, agent count settings
│   └── projects.yaml          # Project registry
│
├── queue/                     # Communication (source of truth)
│   ├── shogun_to_karo.yaml
│   ├── tasks/ashigaru{1-N}.yaml
│   ├── reports/ashigaru{1-N}_report.yaml
│   ├── denrei/
│   │   ├── tasks/denrei{1-2}.yaml
│   │   └── reports/denrei{1-2}_report.yaml
│   ├── shinobi/reports/
│   └── gunshi/reports/
│
├── scripts/                   # Operational tools
│   └── extract-section.sh     # Markdown section extractor (bash+awk)
│
├── skills/                    # Skill definitions
│   ├── context-health.md      # /compact templates, mixed strategy
│   ├── shinobi-manual.md      # Gemini summoning guide
│   ├── architecture.md        # System architecture details
│   └── generated/             # Skills created during operation
│
├── templates/                 # YAML/MD templates for agents
├── context/                   # Project-specific context files
├── logs/archive/              # Archived commands, reports, dashboard history
├── memory/                    # Memory MCP persistent storage
├── dashboard.md               # Human-readable status board
└── CLAUDE.md                  # System instructions (auto-loaded)
```

---

## Troubleshooting

<details>
<summary><b>Agents asking for permissions?</b></summary>

Agents should start with `--dangerously-skip-permissions`. This is handled automatically by `shutsujin_departure.sh`.

</details>

<details>
<summary><b>MCP tools not loading?</b></summary>

MCP tools are lazy-loaded. Search first, then use:
```
ToolSearch("select:mcp__memory__read_graph")
mcp__memory__read_graph()
```

</details>

<details>
<summary><b>Agent crashed?</b></summary>

Don't use `css`/`csm` aliases inside an existing tmux session (causes nesting). Instead:

```bash
# From the crashed pane:
claude --model opus --dangerously-skip-permissions

# Or from another pane:
tmux respawn-pane -t shogun:0.0 -k 'claude --model opus --dangerously-skip-permissions'
```

</details>

<details>
<summary><b>Workers stuck?</b></summary>

```bash
tmux attach-session -t multiagent
# Ctrl+B then 0-8 to switch panes
```

</details>

---

## tmux Quick Reference

| Command | Description |
|---------|-------------|
| `tmux attach -t shogun` | Connect to the Shogun |
| `tmux attach -t multiagent` | Connect to workers |
| `Ctrl+B` then `0`–`8` | Switch panes |
| `Ctrl+B` then `d` | Detach (agents keep running) |

Mouse support is enabled by default (`set -g mouse on` in `~/.tmux.conf`, configured by `first_setup.sh`). Scroll, click to focus, drag to resize.

---

## Contributing

Issues and pull requests are welcome.

- **Bug reports**: Open an issue with reproduction steps
- **Feature ideas**: Open a discussion first
- **Skills**: Skills are personal by design and not included in this repo

## Credits

Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa, via [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) by yohey-w.

## License

[MIT](LICENSE)

---

<div align="center">

**One command. Your army. Zero coordination cost.**

⭐ Star this repo if you find it useful — it helps others discover it.

</div>
