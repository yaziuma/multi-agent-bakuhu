<div align="center">

# multi-agent-bakuhu

**Command your AI army like a feudal warlord.**

Run multiple AI coding agents in parallel — **Claude Code, OpenAI Codex, GitHub Copilot, Kimi Code** — orchestrated through a samurai-inspired hierarchy with zero coordination overhead.

**Talk Coding, not Vibe Coding. Speak to your phone, AI executes.**

[![GitHub Stars](https://img.shields.io/github/stars/yaziuma/multi-agent-bakuhu?style=social)](https://github.com/yaziuma/multi-agent-bakuhu)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![v3.0 Multi-CLI](https://img.shields.io/badge/v3.0-Multi--CLI_Support-ff6600?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxNiIgaGVpZ2h0PSIxNiI+PHRleHQgeD0iMCIgeT0iMTIiIGZvbnQtc2l6ZT0iMTIiPuKalTwvdGV4dD48L3N2Zz4=)](https://github.com/yaziuma/multi-agent-bakuhu)
[![Shell](https://img.shields.io/badge/Shell%2FBash-100%25-green)]()

[English](README.md) | [日本語](README_ja.md)

</div>

---

## What is this?

**multi-agent-bakuhu** is a system that runs multiple AI coding CLI instances simultaneously, orchestrating them like a feudal Japanese army. Supports **Claude Code**, **OpenAI Codex**, **GitHub Copilot**, and **Kimi Code**.

**Why use it?**
- One command spawns multiple AI workers executing in parallel
- Zero wait time — give your next order while tasks run in the background
- AI remembers your preferences across sessions (Memory MCP)
- Real-time progress on a dashboard

```
        You (上様 / The Lord)
             │
             ▼  Give orders
      ┌─────────────┐
      │   SHOGUN    │  ← Receives your command, delegates instantly
      └──────┬──────┘
             │  YAML + tmux
      ┌──────▼──────┐
      │    KARO     │  ← Distributes tasks to workers
      └──────┬──────┘
             │
    ┌─┬─┬─┬─┴─┬─┬─┬─┐
    │1│2│3│D1│D2│Sh│Gu│  ← Workers execute in parallel
    └─┴─┴─┴─┴─┴─┴─┴─┘
    ASHIGARU DENREI EXTERNAL
```

> Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa, via [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) by yohey-w. Extensively redesigned with external agent integration (Gemini, Codex), context health management, archival systems, and a deeper feudal hierarchy.

---

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

**Zero coordination overhead** — Agents talk through YAML files on disk. The only API calls are for actual work, not orchestration. Run N agents and pay only for N agents' work.

**Full transparency** — Every agent runs in a visible tmux pane. Every instruction, report, and decision is a plain YAML file you can read, diff, and version-control. No black boxes.

**Battle-tested hierarchy** — The Shogun → Karo → Ashigaru chain of command prevents conflicts by design: clear ownership, dedicated files per agent, event-driven communication, no polling.

**Multi-model orchestration** — Claude (Opus/Sonnet/Haiku), Gemini, and Codex work together. Each model is deployed where its strengths matter most.

---

## Why CLI (Not API)?

Most AI coding tools charge per token. Running multiple Opus-grade agents through the API costs **$100+/hour**. CLI subscriptions flip this:

| | API (Per-Token) | CLI (Flat-Rate) |
|---|---|---|
| **Multiple agents × Opus** | ~$100+/hour | ~$200/month |
| **Cost predictability** | Unpredictable spikes | Fixed monthly bill |
| **Usage anxiety** | Every token counts | Unlimited |
| **Experimentation budget** | Constrained | Deploy freely |

**"Use AI recklessly"** — With flat-rate CLI subscriptions, deploy multiple agents without hesitation. The cost is the same whether they work 1 hour or 24 hours. No more choosing between "good enough" and "thorough" — just run more agents.

### Multi-CLI Support

Bakuhu isn't locked to one vendor. The system supports 4 CLI tools, each with unique strengths:

| CLI | Key Strength | Default Model |
|-----|-------------|---------------|
| **Claude Code** | Battle-tested tmux integration, Memory MCP, dedicated file tools (Read/Write/Edit/Glob/Grep) | Claude Sonnet 4.5 |
| **OpenAI Codex** | Sandbox execution, JSONL structured output, `codex exec` headless mode | gpt-5.3-codex |
| **GitHub Copilot** | Built-in GitHub MCP, 4 specialized agents (Explore/Task/Plan/Code-review), `/delegate` to coding agent | Claude Sonnet 4.5 |
| **Kimi Code** | Free tier available, strong multilingual support | Kimi k2 |

A unified instruction build system generates CLI-specific instruction files from shared templates:

```
instructions/
├── common/              # Shared rules (all CLIs)
├── cli_specific/        # CLI-specific tool descriptions
│   ├── claude_tools.md  # Claude Code tools & features
│   └── copilot_tools.md # GitHub Copilot CLI tools & features
└── roles/               # Role definitions (shogun, karo, ashigaru)
    ↓ build
CLAUDE.md / AGENTS.md / copilot-instructions.md  ← Generated per CLI
```

One source of truth, zero sync drift. Change a rule once, all CLIs get it.

---

## Architecture

### Agent roles

| Agent | Role | Model | Count |
|-------|------|-------|-------|
| **Shogun (将軍)** | Commander — receives your orders, delegates to Karo | Opus | 1 |
| **Karo (家老)** | Steward — breaks tasks down, assigns to Ashigaru, maintains dashboard | Opus | 1 (+1 standby) |
| **Ashigaru (足軽)** | Foot soldiers — execute tasks in parallel | Sonnet/Opus | Configurable (default: 3) |
| **Denrei (伝令)** | Messengers — summon and relay with external agents | Haiku | 2 |
| **Shinobi (忍び)** | Intelligence — research, web search, large document analysis | Gemini | External |
| **Kyakusho (客将)** | Strategist — deep reasoning, code review, design decisions | Codex | External |

### Agent Team (Claude Code Sub-agents)

Separate from the tmux hierarchy, Bakuhu uses **Claude Code's native Agent Team feature** for complex development tasks requiring orchestration. These agents run as sub-processes within Claude Code, not as tmux panes.

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| **Bugyo (奉行)** | Task Commander — breaks down tasks, coordinates team, validates quality. Never writes code directly; delegates to Ashigaru | inherit | All (delegate mode) |
| **Ashigaru (足軽)** | Implementation Worker — writes code, runs tests, debugs. Adheres to quality standards: `ruff check + format + pytest` | Sonnet | All |
| **Goikenban (御意見番)** | Code Reviewer — identifies problems, security risks, edge cases. Read-only (no Write/Edit access). Reports in 3 levels: Critical / Warning / Suggestion | Opus | Read, Grep, Glob, Bash |

**Workflow:**
1. Bugyo receives task → decomposes into subtasks → creates TaskList
2. Bugyo spawns Ashigaru (implementation) and Goikenban (review) via Task tool
3. Ashigaru execute assigned tasks in parallel
4. Goikenban reviews all changes after implementation complete
5. If Critical issues found → Ashigaru fix → re-review cycle
6. Once all Critical issues resolved → Bugyo reports completion and shuts down team

**Key difference from tmux agents:**
- **tmux agents** (Shogun/Karo/Ashigaru/Denrei): Long-lived, coordinated via YAML files, visible in tmux panes
- **Agent Team**: Short-lived, spawned on-demand for specific tasks, coordinated via Claude Code's Task/SendMessage tools, exist only for task duration

**Usage:** Invoke by spawning a Bugyo agent with a complex task description. Bugyo will automatically assemble the team as needed.

> **Note:** Agent Team requires setup. Agents are defined in `.claude/agents/` as YAML + Markdown files. Claude Code's Agent Team feature must be enabled. This system is under active development and setup may be simplified in future versions.

### Communication protocol

- **Downward** (orders): Write YAML → wake target with `tmux send-keys` (or mailbox system)
- **Upward** (reports): Write YAML only (no send-keys to avoid interrupting your input)
- **External agents**: Always summoned via Denrei (never directly)
- **Polling**: Forbidden. Event-driven only. Your API bill stays predictable.

### Event-Driven Communication (Zero Polling)

Agents talk to each other by writing YAML files — like passing notes. **No polling loops, no wasted API calls.**

```
Karo wants to wake Ashigaru 3:

Step 1: Write the message          Step 2: Wake the agent up
┌──────────────────────┐           ┌──────────────────────────┐
│ inbox_write.sh       │           │ inbox_watcher.sh         │
│                      │           │                          │
│ Writes full message  │  file     │ Detects file change      │
│ to ashigaru3.yaml    │──change──▶│ (inotifywait, not poll)  │
│ with flock (no race) │           │                          │
└──────────────────────┘           │ Wakes agent via:         │
                                   │  1. Self-watch (skip)    │
                                   │  2. tmux send-keys       │
                                   │     (short nudge only)   │
                                   └──────────────────────────┘

Step 3: Agent reads its own inbox
┌──────────────────────────────────┐
│ Ashigaru 3 reads ashigaru3.yaml  │
│ → Finds unread messages          │
│ → Processes them                 │
│ → Marks as read                  │
└──────────────────────────────────┘
```

**How the wake-up works:**

| Priority | Method | What happens | When used |
|----------|--------|-------------|-----------|
| 1st | **Self-Watch** | Agent watches its own inbox file — wakes itself, no nudge needed | Agent has its own `inotifywait` running |
| 2nd | **tmux send-keys** | Sends short nudge via `tmux send-keys` (text and Enter sent separately for Codex CLI compatibility) | Default fallback if self-watch misses |

**3-Phase Escalation** — If agent doesn't respond to nudge:

| Phase | Timing | Action |
|-------|--------|--------|
| Phase 1 | 0-2 min | Standard nudge (`inbox3` text + Enter) |
| Phase 2 | 2-4 min | Escape×2 + C-c to reset cursor, then nudge |
| Phase 3 | 4+ min | Send `/clear` to force session reset (max once per 5 min) |

**Key design choices:**
- **Message content is never sent through tmux** — only a short "you have mail" nudge. The agent reads its own file. This eliminates character corruption and transmission hangs.
- **Zero CPU while idle** — `inotifywait` blocks on a kernel event (not a poll loop). CPU usage is 0% between messages.
- **Guaranteed delivery** — If the file write succeeded, the message is there. No lost messages, no retries needed.

### Context persistence (4 layers)

Efficient knowledge sharing through a four-layer context system:

| Layer | Location | Purpose |
|-------|----------|---------|
| Layer 1: Memory MCP | `memory/shogun_memory.jsonl` | Cross-project, cross-session long-term memory |
| Layer 2: Project | `config/projects.yaml`, `projects/<id>.yaml`, `context/{project}.md` | Project-specific information and technical knowledge |
| Layer 3: YAML Queue | `queue/shogun_to_karo.yaml`, `queue/tasks/`, `queue/reports/` | Task management — source of truth for instructions and reports |
| Layer 4: Session | CLAUDE.md, instructions/*.md | Working context (wiped by `/clear`) |

This design enables:
- Any Ashigaru can work on any project
- Context persists across agent switches
- Clear separation of concerns
- Knowledge survives across sessions

#### /clear Protocol (Cost Optimization)

As agents work, their session context (Layer 4) grows, increasing API costs. `/clear` wipes session memory and resets costs. Layers 1–3 persist as files, so nothing is lost.

Recovery cost after `/clear`: **~6,800 tokens** (42% improved from v1 — CLAUDE.md YAML conversion + English-only instructions reduced token cost by 70%)

1. CLAUDE.md (auto-loaded) → recognizes itself as part of the system
2. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` → identifies its own number
3. Memory MCP read → restores the Lord's preferences (~700 tokens)
4. Task YAML read → picks up the next assignment (~800 tokens)

The key insight: designing **what not to load** is what drives cost savings.

#### Universal Context Template

All projects use the same 7-section template:

| Section | Purpose |
|---------|---------|
| What | Project overview |
| Why | Goals and success criteria |
| Who | Stakeholders and responsibilities |
| Constraints | Deadlines, budgets, limitations |
| Current State | Progress, next actions, blockers |
| Decisions | Decisions made and their rationale |
| Notes | Free-form observations and ideas |

This unified format enables:
- Quick onboarding for any agent
- Consistent information management across all projects
- Easy handoff between Ashigaru workers

### Identity Isolation v3 (Role-Based Access Control)

Bakuhu enforces role boundaries through **Claude Code PreToolUse hooks**. Each agent can only take actions appropriate to its role — enforced at the tool call level, not by convention.

#### Identity resolution

Every agent's identity is resolved from its **tmux pane ID** via `config/pane_role_map.yaml` — never from MEMORY.md or any user-writable variable. This prevents identity contamination across sessions (a critical bug discovered in 2026-02-20 where agents were impersonating other roles by reading shared MEMORY.md).

```
Session startup (shutsujin_departure.sh)
    ↓
Generates pane_role_map.yaml: { %0: shogun, %1: karo, %2: ashigaru, ... }
Records sha256sum → pane_role_map.yaml.sha256
Records epoch → config/session.epoch
Sets hook_common.sh to read-only (chmod 444)
    ↓
Every tool call (PreToolUse hook):
    get_role() → tmux pane ID → pane_role_map.yaml → role
    check_role_match() → skip if not this role's hook
    Apply role-specific restrictions → exit 0 (allow) or exit 2 (deny)
```

#### Two-layer hook protection

Each role has two dedicated hooks: a **Bash execution guard** and a **file write guard**.

| Hook | What it prevents |
|------|----------------|
| `karo-guard.sh` | Karo running implementation commands (python, pytest, npm, ruff) |
| `ashigaru-write-guard.sh` | Ashigaru editing system config, instructions, or other roles' memory |
| `denrei-write-guard.sh` | Denrei writing source code (messenger stays in its lane) |
| `shogun-guard.sh` / `shogun-write-guard.sh` | Shogun reading/editing source code (delegates only) |
| `global-guard.sh` | **All roles**: destructive operations (rm -rf, git push --force, sudo, kill, curl\|bash, etc.) |

#### Memory separation

Each role has a dedicated memory file. Cross-role writes are blocked at the hook level.

| Role | Memory file | Write access |
|------|-------------|-------------|
| Shogun | `memory/shogun.md` | Shogun only |
| Karo | `memory/karo.md` | Karo only |
| Ashigaru | `memory/ashigaru.md` | Ashigaru only |
| Denrei | `memory/denrei.md` | Denrei only |

`MEMORY.md` (auto-injected into all sessions) contains **only a lookup table** mapping roles to their memory files. No identity information is stored there — writing identity info to a shared file contaminates all agents simultaneously.

#### Policy-as-Data

Role restrictions are defined in YAML files under `.claude/hooks/policies/`, validated against a JSON Schema. This separates **what is forbidden** (auditable data) from **how it's enforced** (code).

#### Startup self-test

`scripts/selftest_hooks.sh` verifies the hook system at session startup:
- All hook files exist with correct execute permissions
- SHA-256 integrity of `hook_common.sh` (the shared hook library)
- JSON Schema validation of all policy YAML files
- Zero-tolerance: any failure blocks the session

---

## External Agents

The Shogun can summon external specialists **via Denrei (messengers)** for tasks that require capabilities beyond Claude Code:

| Agent | Tool | Role | Strengths |
|-------|------|------|-----------|
| **Shinobi (忍び)** | Gemini CLI | Intelligence & Research | 1M token context, Web search, PDF/video analysis |
| **Kyakusho (客将)** | Codex CLI | Strategic Advisor | Deep reasoning, Design decisions, Code review |

**Requirements:**
- **Shinobi**: Requires [Gemini CLI](https://github.com/google/generative-ai-cli) installed separately
- **Kyakusho**: Requires [Codex CLI](https://github.com/openai/codex-cli) installed separately

**Key rules:**
- Shogun/Karo summon external agents **only via Denrei** (forbidden action F006 if done directly)
- Denrei handle the blocking API calls, keeping the command chain responsive
- Ashigaru can summon with explicit permission (`shinobi_allowed: true` in task YAML)

---

## Bottom-Up Skill Discovery

This is the feature no other framework has.

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
Appears in dashboard.md → You approve → Skill created in .claude/commands/
    ↓
Any agent can now invoke /api-endpoint-scaffold
```

Skills grow organically from real work — not from a predefined template library. Your skill set becomes a reflection of **your** workflow.

---

## Context Health Management

Long-running agents accumulate context, driving up API costs. Bakuhu manages this with built-in strategies:

### Context Usage Thresholds

| Status | Usage | Recommended Action |
|--------|-------|-------------------|
| Healthy | 0-60% | Continue normal work |
| Warning | 60-75% | /compact after current task |
| Danger | 75-85% | /compact immediately |
| Critical | 85%+ | /clear immediately (interrupt work if needed) |

**/compact must use custom instructions.** See `skills/context-health.md` for templates and mixed strategies.

### Agent-Specific Strategies

| Agent | Strategy | Rationale |
|-------|----------|-----------|
| **Shogun** | `/compact` priority | Context preservation is critical |
| **Karo** | Mixed: `/compact` 3× → `/clear` 1× | Balance context retention and cost (30% savings) |
| **Ashigaru** | `/clear` after each task | Clean slate per task, minimal recovery cost |
| **Denrei** | `/clear` after each task | Stateless by design |

A **standby Karo** (hot spare) can take over when the primary Karo needs `/clear`, ensuring continuity of operations.

### Archival system

Completed commands, old reports, and resolved dashboard sections are archived (never deleted) to `logs/archive/YYYY-MM-DD/`. The `scripts/extract-section.sh` tool enables selective reading of dashboard sections, reducing token consumption during compaction recovery.

---

## Quick Start

### Windows (WSL2)

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **Download the repository**

[Download ZIP](https://github.com/yaziuma/multi-agent-bakuhu/archive/refs/heads/main.zip) and extract to `C:\tools\multi-agent-bakuhu`

*Or use git:* `git clone https://github.com/yaziuma/multi-agent-bakuhu.git C:\tools\multi-agent-bakuhu`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **Run `install.bat`**

Right-click → "Run as Administrator" (if WSL2 is not installed). Sets up WSL2 + Ubuntu automatically.

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Open Ubuntu and run** (first time only)

```bash
cd /mnt/c/tools/multi-agent-bakuhu
./first_setup.sh
```

</td>
</tr>
<tr>
<td>

**Step 4**

</td>
<td>

✅ **Deploy!**

```bash
./shutsujin_departure.sh
```

</td>
</tr>
</table>

#### First-time only: Authentication

After `first_setup.sh`, run these commands once to authenticate:

```bash
# 1. Apply PATH changes
source ~/.bashrc

# 2. OAuth login + Bypass Permissions approval (one command)
claude --dangerously-skip-permissions
#    → Browser opens → Log in with Anthropic account → Return to CLI
#    → "Bypass Permissions" prompt appears → Select "Yes, I accept" (↓ to option 2, Enter)
#    → Type /exit to quit
```

This saves credentials to `~/.claude/` — you won't need to do it again.

#### Daily startup

Open an **Ubuntu terminal** (WSL) and run:

```bash
cd /mnt/c/tools/multi-agent-bakuhu
./shutsujin_departure.sh
```

### 📱 Mobile Access (Command from anywhere)

Control your AI army from your phone — bed, café, or bathroom.

**Requirements (all free):**

| Name | In a nutshell | Role |
|------|--------------|------|
| [Tailscale](https://tailscale.com/) | A road to your home from anywhere | Connect to your home PC from anywhere |
| SSH | The feet that walk that road | Log into your home PC through Tailscale |
| [Termux](https://termux.dev/) | A black screen on your phone | Required to use SSH — just install it |

**Setup:**

1. Install Tailscale on both WSL and your phone
2. In WSL (auth key method — browser not needed):
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscaled &
   sudo tailscale up --authkey tskey-auth-XXXXXXXXXXXX
   sudo service ssh start
   ```
3. In Termux on your phone:
   ```sh
   pkg update && pkg install openssh
   ssh youruser@your-tailscale-ip
   css    # Connect to Shogun
   ```
4. Open a new Termux window (+ button) for workers:
   ```sh
   ssh youruser@your-tailscale-ip
   csm    # See all panes
   ```

**Disconnect:** Just swipe the Termux window closed. tmux sessions survive — agents keep working.

**Voice input:** Use your phone's voice keyboard to speak commands. The Shogun understands natural language, so typos from speech-to-text don't matter.

**Even simpler:** With ntfy configured, you can receive notifications and send commands directly from the ntfy app — no SSH required.

---

<details>
<summary>🐧 <b>Linux / macOS</b> (click to expand)</summary>

### First-time setup

```bash
# 1. Clone
git clone https://github.com/yaziuma/multi-agent-bakuhu.git ~/multi-agent-bakuhu
cd ~/multi-agent-bakuhu

# 2. Make scripts executable
chmod +x *.sh

# 3. Run first-time setup
./first_setup.sh
```

### Daily startup

```bash
cd ~/multi-agent-bakuhu
./shutsujin_departure.sh
```

</details>

---

<details>
<summary>❓ <b>What is WSL2? Why is it needed?</b> (click to expand)</summary>

### About WSL2

**WSL2 (Windows Subsystem for Linux)** lets you run Linux inside Windows. This system uses `tmux` (a Linux tool) to manage multiple AI agents, so WSL2 is required on Windows.

### If you don't have WSL2 yet

No problem! Running `install.bat` will:
1. Check if WSL2 is installed (auto-install if not)
2. Check if Ubuntu is installed (auto-install if not)
3. Guide you through next steps (running `first_setup.sh`)

**Quick install command** (run PowerShell as Administrator):
```powershell
wsl --install
```

Then restart your computer and run `install.bat` again.

</details>

---

<details>
<summary>📋 <b>Script Reference</b> (click to expand)</summary>

| Script | Purpose | When to run |
|--------|---------|-------------|
| `install.bat` | Windows: WSL2 + Ubuntu setup | First time only |
| `first_setup.sh` | Install tmux, Node.js, Claude Code CLI + Memory MCP config | First time only |
| `shutsujin_departure.sh` | Create tmux sessions + launch Claude Code + load instructions + start ntfy listener | Daily |

### What `install.bat` does automatically:
- ✅ Checks if WSL2 is installed (guides you if not)
- ✅ Checks if Ubuntu is installed (guides you if not)
- ✅ Shows next steps (how to run `first_setup.sh`)

### What `shutsujin_departure.sh` does:
- ✅ Creates tmux sessions (shogun + multiagent)
- ✅ Launches Claude Code on all agents
- ✅ Auto-loads instruction files for each agent
- ✅ Resets queue files for a fresh state
- ✅ Starts ntfy listener for phone notifications (if configured)

**After running, all agents are ready to receive commands!**

</details>

---

<details>
<summary>🔧 <b>Manual Requirements</b> (click to expand)</summary>

If you prefer to install dependencies manually:

| Requirement | Installation | Notes |
|-------------|-------------|-------|
| WSL2 + Ubuntu | `wsl --install` in PowerShell | Windows only |
| Set Ubuntu as default | `wsl --set-default Ubuntu` | Required for scripts to work |
| tmux | `sudo apt install tmux` | Terminal multiplexer |
| Node.js v20+ | `nvm install 20` | Required for MCP servers |
| Claude Code CLI | `curl -fsSL https://claude.ai/install.sh \| bash` | Official Anthropic CLI (native version recommended; npm version deprecated) |

</details>

---

### After Setup

**Multiple AI agents** are automatically launched:

| Agent | Role | Count |
|-------|------|-------|
| 🏯 Shogun | Supreme commander — receives your orders | 1 |
| 📋 Karo | Manager — distributes tasks | 1 |
| ⚔️ Ashigaru | Workers — execute tasks in parallel | Configurable (default: 3) |
| 📨 Denrei | Messengers — summon external agents | 2 |

Two tmux sessions are created:
- `shogun` — connect here to give commands
- `multiagent` — workers running in the background

---

## How It Works

### Step 1: Connect to the Shogun

After running `shutsujin_departure.sh`, all agents automatically load their instructions and are ready.

Open a new terminal and connect:

```bash
tmux attach-session -t shogun
```

### Step 2: Give your first order

The Shogun is already initialized — just give a command:

```
Research the top 5 JavaScript frameworks and create a comparison table
```

The Shogun will:
1. Write the task to a YAML file
2. Notify the Karo (manager)
3. Return control to you immediately — no waiting!

Meanwhile, the Karo distributes tasks to Ashigaru workers for parallel execution.

### Step 3: Check progress

Open `dashboard.md` in your editor for a real-time status view:

```markdown
## In Progress
| Worker | Task | Status |
|--------|------|--------|
| Ashigaru 1 | Research React | Running |
| Ashigaru 2 | Research Vue | Running |
| Ashigaru 3 | Research Angular | Completed |
```

### Detailed flow

```
You: "Research the top 5 MCP servers and create a comparison table"
```

The Shogun writes the task to `queue/shogun_to_karo.yaml` and wakes the Karo. Control returns to you immediately.

The Karo breaks the task into subtasks:

| Worker | Assignment |
|--------|-----------|
| Ashigaru 1 | Research Notion MCP |
| Ashigaru 2 | Research GitHub MCP |
| Ashigaru 3 | Research Playwright MCP |
| Denrei 1 | Summon Shinobi for web search (if needed) |

All Ashigaru research simultaneously. Results appear in `dashboard.md` as they complete.

---

## Key Features

### ⚡ 1. Parallel Execution

One command spawns multiple parallel tasks:

```
You: "Research 5 MCP servers"
→ Multiple Ashigaru start researching simultaneously
→ Results in minutes, not hours
```

### 🔄 2. Non-Blocking Workflow

The Shogun delegates instantly and returns control to you:

```
You: Command → Shogun: Delegates → You: Give next command immediately
                                       ↓
                       Workers: Execute in background
                                       ↓
                       Dashboard: Shows results
```

No waiting for long tasks to finish.

### 🧠 3. Cross-Session Memory (Memory MCP)

Your AI remembers your preferences:

```
Session 1: Tell it "I prefer simple approaches"
            → Saved to Memory MCP

Session 2: AI loads memory on startup
            → Stops suggesting complex solutions
```

### 📸 4. Screenshot Integration

VSCode's Claude Code extension lets you paste screenshots to explain issues. This CLI system provides the same capability:

```yaml
# Set your screenshot folder in config/settings.yaml
screenshot:
  path: "/mnt/c/Users/YourName/Pictures/Screenshots"
```

```
# Just tell the Shogun:
You: "Check the latest screenshot"
You: "Look at the last 2 screenshots"
→ AI instantly reads and analyzes your screen captures
```

**Windows tip:** Press `Win + Shift + S` to take screenshots. Set the save path in `settings.yaml` for seamless integration.

Use cases:
- Explain UI bugs visually
- Show error messages
- Compare before/after states

### 🖼️ 5. Pane Border Task Display

Each tmux pane shows the agent's current task directly on its border:

```
┌ ashigaru1 (Sonnet) VF requirements ─┬ ashigaru3 (Opus) API research ──────┐
│                                      │                                     │
│  Working on SayTask requirements     │  Researching REST API patterns      │
│                                      │                                     │
├ ashigaru2 (Sonnet) ─────────────────┼ denrei1 (Haiku) ────────────────────┤
│                                      │                                     │
│  (idle — waiting for assignment)     │  Summoning Shinobi for web search   │
│                                      │                                     │
└──────────────────────────────────────┴─────────────────────────────────────┘
```

- **Working**: `ashigaru1 (Sonnet) VF requirements` — agent name, model, and task summary
- **Idle**: `ashigaru1 (Sonnet)` — model name only, no task
- Updated automatically by the Karo when assigning or completing tasks
- Glance at all panes to instantly know who's doing what

### 🔊 6. Shout Mode (Battle Cries)

When an Ashigaru completes a task, it shouts a personalized battle cry in the tmux pane — a visual reminder that your army is working hard.

```
┌ ashigaru1 (Sonnet) ──────────┬ ashigaru2 (Sonnet) ──────────┐
│                               │                               │
│  ⚔️ 足軽1号、先陣切った！     │  🔥 足軽2号、二番槍の意地！   │
│  八刃一志！                   │  八刃一志！                   │
│  ❯                            │  ❯                            │
└───────────────────────────────┴───────────────────────────────┘
```

**How it works:**

The Karo writes an `echo_message` field in each task YAML. After completing all work (report + inbox notification), the Ashigaru runs `echo` as its **final action**. The message stays visible above the `❯` prompt.

```yaml
# In the task YAML (written by Karo)
task:
  task_id: subtask_001
  description: "Create comparison table"
  echo_message: "🔥 足軽1号、先陣を切って参る！八刃一志！"
```

**Shout mode is the default.** To disable (saves API tokens on the echo call):

```bash
./shutsujin_departure.sh --silent    # No battle cries
./shutsujin_departure.sh             # Default: shout mode (battle cries enabled)
```

Silent mode sets `DISPLAY_MODE=silent` as a tmux environment variable. The Karo checks this when writing task YAMLs and omits the `echo_message` field.

### 📱 7. Phone Notifications (ntfy)

Two-way communication between your phone and the Shogun — no SSH, no Tailscale, no server needed.

| Direction | How it works |
|-----------|-------------|
| **Phone → Shogun** | Send a message from the ntfy app → `ntfy_listener.sh` receives it via streaming → Shogun processes automatically |
| **Karo → Phone (direct)** | When Karo updates `dashboard.md`, it sends push notifications directly via `scripts/ntfy.sh` — **Shogun is bypassed** (Shogun is for human interaction, not progress reporting) |

```
📱 You (from bed)          🏯 Shogun
    │                          │
    │  "Research React 19"     │
    ├─────────────────────────►│
    │    (ntfy message)        │  → Delegates to Karo → Ashigaru work
    │                          │
    │  "✅ cmd_042 complete"   │
    │◄─────────────────────────┤
    │    (push notification)   │
```

**Setup:**
1. Add `ntfy_topic: "shogun-yourname"` to `config/settings.yaml`
2. Install the [ntfy app](https://ntfy.sh) on your phone and subscribe to the same topic
3. `shutsujin_departure.sh` automatically starts the listener — no extra steps

**Notification examples:**

| Event | Notification |
|-------|-------------|
| Command completed | `✅ cmd_042 complete — 5/5 subtasks done` |
| Task failed | `❌ subtask_042c failed — API rate limit` |
| Action required | `🚨 Action needed: approve skill candidate` |
| Streak update | `🔥 3-day streak! 12/12 tasks today` |

Free, no account required, no server to maintain. Uses [ntfy.sh](https://ntfy.sh) — an open-source push notification service.

> **⚠️ Security:** Your topic name is your password. Anyone who knows it can read your notifications and send messages to your Shogun. Choose a hard-to-guess name and **never share it publicly** (e.g., in screenshots, blog posts, or GitHub commits).

**Verify it works:**

```bash
# Send a test notification to your phone
bash scripts/ntfy.sh "Test notification from Shogun 🏯"
```

If your phone receives the notification, you're all set. If not, check:
- `config/settings.yaml` has `ntfy_topic` set (not empty, no extra quotes)
- The ntfy app on your phone is subscribed to **the exact same topic name**
- Your phone has internet access and ntfy notifications are enabled

**Sending commands from your phone:**

1. Open the ntfy app on your phone
2. Tap your subscribed topic
3. Type a message (e.g., `Research React 19 best practices`) and send
4. `ntfy_listener.sh` receives it, writes to `queue/ntfy_inbox.yaml`, and wakes the Shogun
5. The Shogun reads the message and processes it through the normal Karo → Ashigaru pipeline

Any text you send becomes a command. Write it like you'd talk to the Shogun — no special syntax needed.

**Manual listener start** (if not using `shutsujin_departure.sh`):

```bash
# Start the listener in the background
nohup bash scripts/ntfy_listener.sh &>/dev/null &

# Check if it's running
pgrep -f ntfy_listener.sh

# View listener logs (stderr output)
bash scripts/ntfy_listener.sh  # Run in foreground to see logs
```

The listener automatically reconnects if the connection drops. `shutsujin_departure.sh` starts it automatically on deployment — you only need manual start if you skipped the deployment script.

**Troubleshooting:**

| Problem | Fix |
|---------|-----|
| No notifications on phone | Check topic name matches exactly in `settings.yaml` and ntfy app |
| Listener not starting | Run `bash scripts/ntfy_listener.sh` in foreground to see errors |
| Phone → Shogun not working | Verify listener is running: `pgrep -f ntfy_listener.sh` |
| Messages not reaching Shogun | Check `queue/ntfy_inbox.yaml` — if message is there, Shogun may be busy |
| "ntfy_topic not configured" error | Add `ntfy_topic: "your-topic"` to `config/settings.yaml` |
| Duplicate notifications | Normal on reconnect — Shogun deduplicates by message ID |
| Changed topic name but no notifications | The listener must be restarted: `pkill -f ntfy_listener.sh && nohup bash scripts/ntfy_listener.sh &>/dev/null &` |

#### SayTask Notifications

Behavioral psychology-driven motivation through your notification feed:

- **Streak tracking**: Consecutive completion days counted in `saytask/streaks.yaml` — maintaining streaks leverages loss aversion to sustain momentum
- **Eat the Frog** 🐸: The hardest task of the day is marked as the "Frog." Completing it triggers a special celebration notification
- **Daily progress**: `12/12 tasks today` — visual completion feedback reinforces the Arbeitslust effect (joy of work-in-progress)

---

## 🗣️ SayTask — Task Management for People Who Hate Task Management

### What is SayTask?

**Task management for people who hate task management. Just speak to your phone.**

**Talk Coding, not Vibe Coding.** Speak your tasks, AI organizes them. No typing, no opening apps, no friction.

- **Target audience**: People who installed Todoist but stopped opening it after 3 days
- Your enemy isn't other apps — it's doing nothing. The competition is inaction, not another productivity tool
- Zero UI. Zero typing. Zero app-opening. Just talk

> *"Your enemy isn't other apps — it's doing nothing."*

### How it Works

1. Install the [ntfy app](https://ntfy.sh) (free, no account needed)
2. Speak to your phone: *"dentist tomorrow"*, *"invoice due Friday"*
3. AI auto-organizes → morning notification: *"here's your day"*

```
 🗣️ "Buy milk, dentist tomorrow, invoice due Friday"
       │
       ▼
 ┌──────────────────┐
 │  ntfy → Shogun   │  AI auto-categorize, parse dates, set priorities
 └────────┬─────────┘
          │
          ▼
 ┌──────────────────┐
 │   tasks.yaml     │  Structured storage (local, never leaves your machine)
 └────────┬─────────┘
          │
          ▼
 📱 Morning notification:
    "Today: 🐸 Invoice due · 🦷 Dentist 3pm · 🛒 Buy milk"
```

### Use Cases

- 🛏️ **In bed**: *"Gotta submit the report tomorrow"* — captured before you forget, no fumbling for a notebook
- 🚗 **While driving**: *"Don't forget the estimate for client A"* — hands-free, eyes on the road
- 💻 **Mid-work**: *"Oh, need to buy milk"* — dump it instantly and stay in flow
- 🌅 **Wake up**: Today's tasks already waiting in your notifications — no app to open, no inbox to check
- 🐸 **Eat the Frog**: AI picks your hardest task each morning — ignore it or conquer it first

### FAQ

**Q: How is this different from other task apps?**
A: You never open an app. Just speak. Zero friction. Most task apps fail because people stop opening them. SayTask removes that step entirely.

**Q: Can I use SayTask without the full Bakuhu system?**
A: SayTask is a feature of Bakuhu. Bakuhu also works as a standalone multi-agent development platform — you get both capabilities in one system.

**Q: What's the Frog 🐸?**
A: Every morning, AI picks your hardest task — the one you'd rather avoid. Tackle it first (the "Eat the Frog" method) or ignore it. Your call.

**Q: Is it free?**
A: Everything is free and open-source. ntfy is free too. No account, no server, no subscription.

**Q: Where is my data stored?**
A: Local YAML files on your machine. Nothing is sent to the cloud. Your tasks never leave your device.

**Q: What if I say something vague like "that thing for work"?**
A: AI does its best to categorize and schedule it. You can always refine later — but the point is capturing the thought before it disappears.

### SayTask vs cmd Pipeline

Bakuhu has two complementary task systems:

| Capability | SayTask (Voice Layer) | cmd Pipeline (AI Execution) |
|---|:-:|:-:|
| Voice input → task creation | ✅ | — |
| Morning notification digest | ✅ | — |
| Eat the Frog 🐸 selection | ✅ | — |
| Streak tracking | ✅ | ✅ |
| AI-executed tasks (multi-step) | — | ✅ |
| Multiple-agent parallel execution | — | ✅ |

SayTask handles personal productivity (capture → schedule → remind). The cmd pipeline handles complex work (research, code, multi-step tasks). Both share streak tracking — completing either type of task counts toward your daily streak.

---

## Model Settings

| Agent | Default Model | Thinking | Rationale |
|-------|--------------|----------|-----------|
| Shogun | Opus | **Enabled (high)** | Strategic discussions, research, and policy design require deep reasoning. Use `--shogun-no-thinking` to disable for relay-only mode |
| Karo | Opus | Enabled | Task distribution requires careful judgment |
| Ashigaru 1–N | Sonnet / Opus | Enabled | Cost-efficient for standard tasks (Sonnet) / Full capability for complex tasks (Opus) |
| Denrei 1–2 | Haiku | Disabled | Relay tasks only |

The Shogun serves as the Lord's strategic advisor — not just a task relay. Strategic discussions, research analysis, and policy design are Bloom's Taxonomy Level 4–6 (analysis, evaluation, creation), requiring Thinking mode enabled. For relay-only use, disable with `--shogun-no-thinking`.

### Battle Formations

| Formation | Ashigaru 1–N | Command |
|-----------|-------------|---------|
| **Normal** (default) | Sonnet | `./shutsujin_departure.sh` |
| **Battle** (`-k` flag) | Opus | `./shutsujin_departure.sh -k` |

By default, Ashigaru run on the cheaper Sonnet model. When it's crunch time, switch to Battle formation with `-k` (`--kessen`) for all-Opus maximum capability. The Karo can also promote individual Ashigaru mid-session with `/model opus` when a specific task demands it.

### Bloom's Taxonomy Task Classification

Tasks are classified using Bloom's Taxonomy to optimize model assignment:

| Level | Category | Description | Model |
|-------|----------|-------------|-------|
| L1 | Remember | Recall facts, copy, list | Sonnet |
| L2 | Understand | Explain, summarize, paraphrase | Sonnet |
| L3 | Apply | Execute procedures, implement known patterns | Sonnet |
| L4 | Analyze | Compare, investigate, deconstruct | Opus |
| L5 | Evaluate | Judge, critique, recommend | Opus |
| L6 | Create | Design, build, synthesize new solutions | Opus |

The Karo assigns each subtask a Bloom level and routes it to the appropriate agent tier. This ensures cost-efficient execution: routine work goes to Sonnet, while complex reasoning goes to Opus.

### Task Dependencies (blockedBy)

Tasks can declare dependencies on other tasks using `blockedBy`:

```yaml
# queue/tasks/ashigaru2.yaml
task:
  task_id: subtask_010b
  blockedBy: ["subtask_010a"]  # Waits for ashigaru1's task to complete
  description: "Integrate the API client built by subtask_010a"
```

When a blocking task completes, the Karo automatically unblocks dependent tasks and assigns them to available Ashigaru. This prevents idle waiting and enables efficient pipelining of dependent work.

---

## Philosophy

> "Don't execute tasks mindlessly. Always keep 'fastest × best output' in mind."

The Bakuhu System is built on five core principles:

| Principle | Description |
|-----------|-------------|
| **Autonomous Formation** | Design task formations based on complexity, not templates |
| **Parallelization** | Use subagents to prevent single-point bottlenecks |
| **Research First** | Search for evidence before making decisions |
| **Continuous Learning** | Don't rely solely on model knowledge cutoffs |
| **Triangulation** | Multi-perspective research with integrated authorization |

### Why a hierarchy (Shogun → Karo → Ashigaru)?

1. **Instant response**: The Shogun delegates immediately, returning control to you
2. **Parallel execution**: The Karo distributes to multiple Ashigaru simultaneously
3. **Single responsibility**: Each role is clearly separated — no confusion
4. **Scalability**: Adding more Ashigaru doesn't break the structure
5. **Fault isolation**: One Ashigaru failing doesn't affect the others
6. **Unified reporting**: Only the Shogun communicates with you, keeping information organized

### Why Mailbox System?

Why use files instead of direct messaging between agents?

| Problem with direct messaging | How mailbox solves it |
|-------------------------------|----------------------|
| Agent crashes → message lost | YAML files survive restarts |
| Polling wastes API calls | `inotifywait` is event-driven (zero CPU while idle) |
| Agents interrupt each other | Each agent has its own inbox file — no cross-talk |
| Hard to debug | Open any `.yaml` file to see exact message history |
| Concurrent writes corrupt data | `flock` (exclusive lock) serializes writes automatically |
| Delivery failures (character corruption, hangs) | Message content stays in files — only a short "you have mail" nudge is sent through tmux |

### Agent Identification (@agent_id)

Each pane has a `@agent_id` tmux user option (e.g., `karo`, `ashigaru1`). While `pane_index` can shift when panes are rearranged, `@agent_id` is set at startup by `shutsujin_departure.sh` and never changes.

Agent self-identification:
```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```
The `-t "$TMUX_PANE"` is required. Omitting it returns the active pane's value (whichever pane you're focused on), causing misidentification.

Model names are stored as `@model_name` and current task summaries as `@current_task` — both displayed in the `pane-border-format`. Even if Claude Code overwrites the pane title, these user options persist.

### Why only the Karo updates dashboard.md

1. **Single writer**: Prevents conflicts by limiting updates to one agent
2. **Information aggregation**: The Karo receives all Ashigaru reports, so it has the full picture
3. **Consistency**: All updates pass through a single quality gate
4. **No interruptions**: If the Shogun updated it, it could interrupt the Lord's input

---

## Skills

No skills are included out of the box. Skills emerge organically during operation — you approve candidates from `dashboard.md` as they're discovered.

Invoke skills with `/skill-name`. Just tell the Shogun: "run /skill-name".

### Skill Philosophy

**1. Skills are not committed to the repo**

Skills in `.claude/commands/` are excluded from version control by design:
- Every user's workflow is different
- Rather than imposing generic skills, each user grows their own skill set

**2. How skills are discovered**

```
Ashigaru notices a pattern during work
    ↓
Appears in dashboard.md under "Skill Candidates"
    ↓
You (the Lord) review the proposal
    ↓
If approved, instruct the Karo to create the skill
```

Skills are user-driven. Automatic creation would lead to unmanageable bloat — only keep what you find genuinely useful.

---

## MCP Setup Guide

MCP (Model Context Protocol) servers extend Claude's capabilities. Here's how to set them up:

### What is MCP?

MCP servers give Claude access to external tools:
- **Notion MCP** → Read and write Notion pages
- **GitHub MCP** → Create PRs, manage issues
- **Memory MCP** → Persist memory across sessions

### Installing MCP Servers

Add MCP servers with these commands:

```bash
# 1. Notion - Connect to your Notion workspace
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - Browser automation
claude mcp add playwright -- npx @playwright/mcp@latest
# Note: Run `npx playwright install chromium` first

# 3. GitHub - Repository operations
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat_here -- npx -y @modelcontextprotocol/server-github

# 4. Sequential Thinking - Step-by-step reasoning for complex problems
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# 5. Memory - Cross-session long-term memory (recommended!)
# ✅ Auto-configured by first_setup.sh
# To reconfigure manually:
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/shogun_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory
```

### Verify installation

```bash
claude mcp list
```

All servers should show "Connected" status.

---

## Real-World Use Cases

This system manages **all white-collar tasks**, not just code. Projects can live anywhere on your filesystem.

### Example 1: Research sprint

```
You: "Research the top 5 AI coding assistants and compare them"

What happens:
1. Shogun delegates to Karo
2. Karo assigns:
   - Ashigaru 1: Research GitHub Copilot
   - Ashigaru 2: Research Cursor
   - Ashigaru 3: Research Claude Code
3. All 3 research simultaneously
4. Results compiled in dashboard.md
```

### Example 2: PoC preparation

```
You: "Prepare a PoC for the project on this Notion page: [URL]"

What happens:
1. Karo fetches Notion content via MCP
2. Ashigaru 2: Lists items to verify
3. Ashigaru 3: Investigates technical feasibility
4. Denrei + Shinobi: Deep research on unfamiliar tech
5. All results compiled in dashboard.md — meeting prep done
```

---

## Configuration

### Language

```yaml
# config/settings.yaml
language: ja   # Samurai Japanese only
language: en   # Samurai Japanese + English translation
```

### Screenshot integration

```yaml
# config/settings.yaml
screenshot:
  path: "/mnt/c/Users/YourName/Pictures/Screenshots"
```

Tell the Shogun "check the latest screenshot" and it reads your screen captures for visual context. (`Win+Shift+S` on Windows.)

### ntfy (Phone Notifications)

```yaml
# config/settings.yaml
ntfy_topic: "shogun-yourname"
```

Subscribe to the same topic in the [ntfy app](https://ntfy.sh) on your phone. The listener starts automatically with `shutsujin_departure.sh`.

#### ntfy Authentication (Self-Hosted Servers)

The public ntfy.sh instance requires **no authentication** — the setup above is all you need.

If you run a self-hosted ntfy server with access control enabled, configure authentication:

```bash
# 1. Copy the sample config
cp config/ntfy_auth.env.sample config/ntfy_auth.env

# 2. Edit with your credentials (choose one method)
```

| Method | Config | When to use |
|--------|--------|-------------|
| **Bearer Token** (recommended) | `NTFY_TOKEN=tk_your_token_here` | Self-hosted ntfy with token auth (`ntfy token add <user>`) |
| **Basic Auth** | `NTFY_USER=username` + `NTFY_PASS=password` | Self-hosted ntfy with user/password |
| **None** (default) | Leave file empty or don't create it | Public ntfy.sh — no auth needed |

Priority: Token > Basic > None. If neither is set, no auth headers are sent (backward compatible).

`config/ntfy_auth.env` is excluded from git. See `config/ntfy_auth.env.sample` for details.

---

## Advanced

<details>
<summary><b>Script Architecture</b> (click to expand)</summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                    First-Time Setup (run once)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      ├── Check/guide WSL2 installation                              │
│      └── Check/guide Ubuntu installation                            │
│                                                                     │
│  first_setup.sh (run manually in Ubuntu/WSL)                        │
│      │                                                              │
│      ├── Check/install tmux                                         │
│      ├── Check/install Node.js v20+ (via nvm)                      │
│      ├── Check/install Claude Code CLI (native version)             │
│      │       ※ Proposes migration if npm version detected           │
│      └── Configure Memory MCP server                                │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                    Daily Startup (run every day)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  shutsujin_departure.sh                                             │
│      │                                                              │
│      ├──▶ Create tmux sessions                                      │
│      │         • "shogun" session (1 pane)                          │
│      │         • "multiagent" session (N panes, grid)              │
│      │                                                              │
│      ├──▶ Reset queue files and dashboard                           │
│      │                                                              │
│      └──▶ Launch Claude Code on all agents                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>shutsujin_departure.sh Options</b> (click to expand)</summary>

```bash
# Default: Full startup (tmux sessions + Claude Code launch)
./shutsujin_departure.sh

# Session setup only (no Claude Code launch)
./shutsujin_departure.sh -s
./shutsujin_departure.sh --setup-only

# Clean task queues (preserves command history)
./shutsujin_departure.sh -c
./shutsujin_departure.sh --clean

# Battle formation: All Ashigaru on Opus (max capability, higher cost)
./shutsujin_departure.sh -k
./shutsujin_departure.sh --kessen

# Silent mode: Disable battle cries (saves API tokens on echo calls)
./shutsujin_departure.sh -S
./shutsujin_departure.sh --silent

# Full startup + open Windows Terminal tabs
./shutsujin_departure.sh -t
./shutsujin_departure.sh --terminal

# Shogun relay-only mode: Disable Shogun's thinking (cost savings)
./shutsujin_departure.sh --shogun-no-thinking

# Show help
./shutsujin_departure.sh -h
./shutsujin_departure.sh --help
```

</details>

<details>
<summary><b>Common Workflows</b> (click to expand)</summary>

**Normal daily use:**
```bash
./shutsujin_departure.sh          # Launch everything
tmux attach-session -t shogun     # Connect and give commands
```

**Debug mode (manual control):**
```bash
./shutsujin_departure.sh -s       # Create sessions only

# Manually launch Claude Code on specific agents
tmux send-keys -t shogun:0 'claude --dangerously-skip-permissions' Enter
tmux send-keys -t multiagent:0.0 'claude --dangerously-skip-permissions' Enter
```

**Restart after crash:**
```bash
# Kill existing sessions
tmux kill-session -t shogun
tmux kill-session -t multiagent

# Fresh start
./shutsujin_departure.sh
```

</details>

<details>
<summary><b>Convenient Aliases</b> (click to expand)</summary>

Running `first_setup.sh` automatically adds these aliases to `~/.bashrc`:

```bash
alias csst='cd /mnt/c/tools/multi-agent-bakuhu && ./shutsujin_departure.sh'
alias css='tmux attach-session -t shogun'      # Connect to Shogun
alias csm='tmux attach-session -t multiagent'  # Connect to Karo + Ashigaru
```

To apply aliases: run `source ~/.bashrc` or restart your terminal (PowerShell: `wsl --shutdown` then reopen).

</details>

---

## File Structure

<details>
<summary><b>Click to expand file structure</b></summary>

```
multi-agent-bakuhu/
│
│  ┌──────────────── Setup Scripts ────────────────────┐
├── install.bat               # Windows: First-time setup
├── first_setup.sh            # Ubuntu/Mac: First-time setup
├── shutsujin_departure.sh    # Daily deployment (auto-loads instructions)
│  └──────────────────────────────────────────────────┘
│
├── instructions/             # Agent behavior definitions
│   ├── shogun.md             # Shogun instructions
│   ├── karo.md               # Karo instructions
│   ├── ashigaru.md           # Ashigaru instructions
│   ├── denrei.md             # Denrei (messenger) instructions
│   ├── shinobi.md            # Shinobi (Gemini) instructions
│   ├── kyakusho.md           # Kyakusho (Codex) instructions
│   └── cli_specific/         # CLI-specific tool descriptions
│       ├── claude_tools.md   # Claude Code tools & features
│       └── copilot_tools.md  # GitHub Copilot CLI tools & features
│
├── lib/
│   ├── cli_adapter.sh        # Multi-CLI adapter (Claude/Codex/Copilot/Kimi)
│   └── ntfy_auth.sh          # ntfy authentication helper
│
├── scripts/                  # Utility scripts
│   ├── inbox_write.sh        # Write messages to agent inbox
│   ├── inbox_watcher.sh      # Watch inbox changes via inotifywait
│   ├── ntfy.sh               # Send push notifications to phone
│   ├── ntfy_listener.sh      # Stream incoming messages from phone
│   ├── extract-section.sh    # Markdown section extractor (bash+awk)
│   ├── selftest_hooks.sh     # Hook integrity self-test (runs at startup)
│   ├── get_pane_id.sh        # Get current tmux pane ID (%N format)
│   ├── get_agent_role.sh     # Get role from pane_role_map.yaml
│   └── lib/
│       └── hook_common.sh    # Shared hook library: role resolution, path normalization, logging (chmod 444)
│
├── .claude/
│   └── hooks/                # Claude Code PreToolUse hooks (Identity Isolation v3)
│       ├── karo-guard.sh              # Karo Bash execution guard
│       ├── karo-write-guard.sh        # Karo file write guard
│       ├── ashigaru-guard.sh          # Ashigaru Bash execution guard
│       ├── ashigaru-write-guard.sh    # Ashigaru file write guard
│       ├── denrei-guard.sh            # Denrei Bash execution guard
│       ├── denrei-write-guard.sh      # Denrei file write guard
│       ├── shogun-guard.sh            # Shogun Bash execution guard
│       ├── shogun-write-guard.sh      # Shogun file write guard
│       ├── global-guard.sh            # Universal destructive operation guard (all roles)
│       └── policies/
│           ├── shogun_policy.yaml     # Shogun role policy (YAML)
│           ├── karo_policy.yaml       # Karo role policy (YAML)
│           ├── ashigaru_policy.yaml   # Ashigaru role policy (YAML)
│           ├── denrei_policy.yaml     # Denrei role policy (YAML)
│           ├── global_policy.yaml     # Global policy (YAML)
│           └── policy_schema.json     # JSON Schema for policy validation
│
├── config/
│   ├── settings.yaml              # Language, ntfy, agent count, and other settings
│   ├── ntfy_auth.env.sample       # ntfy authentication template (self-hosted)
│   ├── projects.yaml              # Project registry
│   ├── pane_role_map.yaml         # Pane ID → role mapping (auto-generated at startup)
│   ├── pane_role_map.yaml.sha256  # Integrity hash for tampering detection
│   └── session.epoch              # Session consistency token (replay attack prevention)
│
├── projects/                 # Project details (excluded from git, contains confidential info)
│   └── <project_id>.yaml    # Full info per project (clients, tasks, Notion links, etc.)
│
├── queue/                    # Communication files
│   ├── shogun_to_karo.yaml   # Shogun → Karo commands
│   ├── ntfy_inbox.yaml       # Incoming messages from phone (ntfy)
│   ├── inbox/                # Per-agent inbox files
│   │   ├── shogun.yaml       # Messages to Shogun
│   │   ├── karo.yaml         # Messages to Karo
│   │   └── ashigaru{1-N}.yaml # Messages to each Ashigaru
│   ├── tasks/                # Per-worker task files
│   │   └── ashigaru{1-N}.yaml
│   ├── reports/              # Worker reports
│   │   └── ashigaru{1-N}_report.yaml
│   ├── denrei/               # Denrei task/report files
│   │   ├── tasks/denrei{1-2}.yaml
│   │   └── reports/denrei{1-2}_report.yaml
│   ├── shinobi/reports/      # Shinobi (Gemini) reports
│   └── kyakusho/reports/     # Kyakusho (Codex) reports
│
├── saytask/                  # Behavioral psychology-driven motivation
│   └── streaks.yaml          # Streak tracking and daily progress
│
├── skills/                   # Skill definitions
│   ├── context-health.md     # /compact templates, mixed strategy
│   ├── shinobi-manual.md     # Gemini summoning guide
│   ├── architecture.md       # System architecture details
│   └── generated/            # Skills created during operation
│
├── templates/                # Report and context templates
│   ├── integ_base.md         # Integration: base template
│   ├── integ_fact.md         # Integration: fact-finding
│   ├── integ_proposal.md     # Integration: proposal
│   ├── integ_code.md         # Integration: code review
│   ├── integ_analysis.md     # Integration: analysis
│   └── context_template.md   # Universal 7-section project context
│
├── context/                  # Project-specific context files
├── logs/archive/             # Archived commands, reports, dashboard history
├── memory/                   # Memory MCP persistent storage (role-separated)
│   ├── MEMORY.md             # Lookup table only: role → memory file (no identity info)
│   ├── shogun.md             # Shogun-only memory (write-guarded)
│   ├── karo.md               # Karo-only memory (write-guarded)
│   ├── ashigaru.md           # Ashigaru-only memory (write-guarded)
│   └── denrei.md             # Denrei-only memory (write-guarded)
├── dashboard.md              # Real-time status board
└── CLAUDE.md                 # System instructions (auto-loaded)
```

</details>

---

## Project Management

This system manages not just its own development, but **all white-collar tasks**. Project folders can be located outside this repository.

### How it works

```
config/projects.yaml          # Project list (ID, name, path, status only)
projects/<project_id>.yaml    # Full details for each project
```

- **`config/projects.yaml`**: A summary list of what projects exist
- **`projects/<id>.yaml`**: Complete details (client info, contracts, tasks, related files, Notion pages, etc.)
- **Project files** (source code, documents, etc.) live in the external folder specified by `path`
- **`projects/` is excluded from git** (contains confidential client information)

### Example

```yaml
# config/projects.yaml
projects:
  - id: client_x
    name: "Client X Consulting"
    path: "/mnt/c/Consulting/client_x"
    status: active

# projects/client_x.yaml
id: client_x
client:
  name: "Client X"
  company: "X Corporation"
contract:
  fee: "monthly"
current_tasks:
  - id: task_001
    name: "System Architecture Review"
    status: in_progress
```

This separation lets the Bakuhu System coordinate across multiple external projects while keeping project details out of version control.

---

## Troubleshooting

<details>
<summary><b>Using npm version of Claude Code CLI?</b></summary>

The npm version (`npm install -g @anthropic-ai/claude-code`) is officially deprecated. Re-run `first_setup.sh` to detect and migrate to the native version.

```bash
# Re-run first_setup.sh
./first_setup.sh

# If npm version is detected:
# ⚠️ npm version of Claude Code CLI detected (officially deprecated)
# Install native version? [Y/n]:

# After selecting Y, uninstall npm version:
npm uninstall -g @anthropic-ai/claude-code
```

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
<summary><b>Agents asking for permissions?</b></summary>

Agents should start with `--dangerously-skip-permissions`. This is handled automatically by `shutsujin_departure.sh`.

</details>

<details>
<summary><b>Workers stuck?</b></summary>

```bash
tmux attach-session -t multiagent
# Ctrl+B then 0-8 to switch panes
```

</details>

<details>
<summary><b>Agent crashed?</b></summary>

**Do NOT use `css`/`csm` aliases to restart inside an existing tmux session.** These aliases create tmux sessions, so running them inside an existing tmux pane causes session nesting — your input breaks and the pane becomes unusable.

**Correct restart methods:**

```bash
# Method 1: Run claude directly in the pane
claude --model opus --dangerously-skip-permissions

# Method 2: Karo force-restarts via respawn-pane (also fixes nesting)
tmux respawn-pane -t shogun:0.0 -k 'claude --model opus --dangerously-skip-permissions'
```

**If you accidentally nested tmux:**
1. Press `Ctrl+B` then `d` to detach (exits the inner session)
2. Run `claude` directly (don't use `css`)
3. If detach doesn't work, use `tmux respawn-pane -k` from another pane to force-reset

</details>

---

## tmux Quick Reference

| Command | Description |
|---------|-------------|
| `tmux attach -t shogun` | Connect to the Shogun |
| `tmux attach -t multiagent` | Connect to workers |
| `Ctrl+B` then `0`–`8` | Switch panes |
| `Ctrl+B` then `d` | Detach (agents keep running) |
| `tmux kill-session -t shogun` | Stop the Shogun session |
| `tmux kill-session -t multiagent` | Stop the worker session |

### Mouse Support

`first_setup.sh` automatically configures `set -g mouse on` in `~/.tmux.conf`, enabling intuitive mouse control:

| Action | Description |
|--------|-------------|
| Mouse wheel | Scroll within a pane (view output history) |
| Click a pane | Switch focus between panes |
| Drag pane border | Resize panes |

Even if you're not comfortable with keyboard shortcuts, you can switch, scroll, and resize panes using just the mouse.

---

## What's New — Identity Isolation v3

Role-based access control, enforced at the hook level. Agents are now **structurally prevented** from acting outside their role.

- **Identity contamination bug fixed** — Agents were reading role identity from shared MEMORY.md, causing mass impersonation (3 of 6 agents claimed to be Karo). Root cause eliminated: identity is now read from tmux pane ID → `pane_role_map.yaml` only
- **Role-based hook system** — 9 role-specific hooks (guard + write-guard per role) + 1 global guard, all enforced via Claude Code `PreToolUse` hooks. Zero trust: every tool call is verified
- **Memory separation** — Each role has a dedicated memory file. Cross-role writes are blocked at the hook level. MEMORY.md contains lookup table only (no identity data)
- **Policy-as-Data** — Role restrictions defined in auditable YAML files under `.claude/hooks/policies/`, validated against JSON Schema
- **Tamper detection** — `pane_role_map.yaml` protected by SHA-256 hash. `hook_common.sh` (shared library) protected by chmod 444 + SHA-256. Session epoch prevents stale map reuse
- **Startup self-test** — `selftest_hooks.sh` verifies the entire hook system before any agent starts work (7 test categories, zero-tolerance)
- **Verified by dynamic testing** — cmd_309 dynamic verification: 11/12 tests PASS. The 1 FAIL (tmux-outside behavior) is intentional by Lord's decree (Agent Team compatibility)

---

## What's New in v3.0 — Multi-CLI

> **Bakuhu is no longer Claude-only.** Mix and match 4 AI coding CLIs in a single army.

- **Multi-CLI as first-class architecture** — `lib/cli_adapter.sh` dynamically selects CLI per agent. Change one line in `settings.yaml` to swap any worker between Claude Code, Codex, Copilot, or Kimi
- **OpenAI Codex CLI integration** — GPT-5.3-codex with `--dangerously-bypass-approvals-and-sandbox` for true autonomous execution. `--no-alt-screen` makes agent activity visible in tmux
- **CLI bypass flag discovery** — `--full-auto` is NOT fully automatic (it's `-a on-request`). Documented the correct flags for all 4 CLIs
- **Hybrid architecture** — Command layer (Shogun + Karo) stays on Claude Code for Memory MCP and mailbox integration. Worker layer (Ashigaru) is CLI-agnostic
- **Community-contributed CLI adapters** — Thanks to [@yuto-ts](https://github.com/yuto-ts) (cli_adapter.sh), [@circlemouth](https://github.com/circlemouth) (Codex support), [@koba6316](https://github.com/koba6316) (task routing)

<details>
<summary><b>What was in v2.0</b></summary>

- **ntfy bidirectional communication** — Send commands from your phone, receive push notifications for task completion
- **SayTask notifications** — Streak tracking, Eat the Frog, behavioral psychology-driven motivation
- **Pane border task display** — See each agent's current task at a glance on the tmux pane border
- **Shout mode** (default) — Ashigaru shout personalized battle cries after completing tasks. Disable with `--silent`
- **Agent self-watch + escalation** — Each agent monitors its own inbox file with `inotifywait` (zero-polling, instant wake-up). Fallback: `tmux send-keys` short nudge (text/Enter sent separately for Codex CLI). 3-phase escalation: standard nudge (0-2min) → Escape×2+nudge (2-4min) → `/clear` force reset (4min+). Linux FS symlink resolves WSL2 9P inotify issues.
- **Agent self-identification** (`@agent_id`) — Stable identity via tmux user options, immune to pane reordering
- **Battle mode** (`-k` flag) — All-Opus formation for maximum capability
- **Task dependency system** (`blockedBy`) — Automatic unblocking of dependent tasks

</details>

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
