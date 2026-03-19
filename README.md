<div align="center">

# multi-agent-bakuhu

**Command your AI army like a feudal warlord.**

Run multiple AI coding agents in parallel — **Claude Code (primary) + Gemini (Shinobi) + Codex (Kyakusho)** — orchestrated through a samurai-inspired hierarchy with zero coordination overhead.

**Talk Coding, not Vibe Coding. Speak to your phone, AI executes.**

[![GitHub Stars](https://img.shields.io/github/stars/yaziuma/multi-agent-bakuhu?style=social)](https://github.com/yaziuma/multi-agent-bakuhu)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell%2FBash-100%25-green)]()

[English](README.md) | [日本語](README_ja.md)

</div>

---

## Quick Start

**Requirements:** tmux, bash 4+, [Claude Code](https://claude.ai/code)

```bash
git clone https://github.com/yaziuma/multi-agent-bakuhu
cd multi-agent-bakuhu
bash first_setup.sh          # one-time setup: config, dependencies, MCP
bash shutsujin_departure.sh  # launch all agents
```

Type a command in the Shogun pane:

> "Research the top 5 JavaScript frameworks and create a comparison table"

Shogun delegates → Karo breaks it down → multiple Ashigaru execute in parallel. Denrei summons Shinobi (Gemini) or Kyakusho (Codex) for specialized work.
You watch the dashboard. That's it.

> **Want to go deeper?** The rest of this README covers architecture, external agents, context health management, and Bakuhu-exclusive features.

---

## What is this?

**multi-agent-bakuhu** is an expanded fork of [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) that orchestrates multiple AI coding agents like a feudal Japanese army. **Claude Code** runs all core agents (Shogun/Karo/Ashigaru/Denrei), while **Gemini** (via Shinobi) and **Codex** (via Kyakusho) are summoned as external specialists for research and strategic reasoning.

**Why use it?**
- One command spawns multiple AI workers executing in parallel
- Zero wait time — give your next order while tasks run in the background
- AI remembers your preferences across sessions (Memory MCP)
- Real-time progress on a dashboard
- Claude, Gemini, and Codex work together in a unified hierarchy

```
        You (上様 / The Lord)
             │
             ▼  Give orders
      ┌─────────────┐
      │   SHOGUN    │  ← Receives your command, delegates instantly
      └──────┬──────┘
             │  YAML + tmux
      ┌──────▼──────┐
      │    KARO     │  ← Distributes tasks, manages dashboard
      └──────┬──────┘
             │
    ┌─┬─┬───┴──┬────────────┐
    │1│2│  D1  │   GUNSHI   │  ← Workers + Messenger + QC
    └─┴─┴──┬───┴────────────┘
  ASHIGARU DENREI  QC &
    1-2      1   Model Router
               │
     ┌─────────┴──────────┐
     ▼                    ▼
┌──────────┐        ┌──────────┐
│  SHINOBI │        │ KYAKUSHO │
│ (Gemini) │        │ (Codex)  │
└──────────┘        └──────────┘
 Intelligence        Strategic
 & Research           Advisor
```

> Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa, via [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) by yohey-w. Extensively redesigned with external agent integration (Gemini, Codex), deeper feudal hierarchy, context health management, hook-based security, and Agent Team support.

---

## Why Bakuhu?

Most multi-agent frameworks burn API tokens on coordination. Bakuhu doesn't.

| | Claude Code `Task` tool | Claude Code Agent Teams | LangGraph | CrewAI | **multi-agent-bakuhu** |
|---|---|---|---|---|---|
| **Architecture** | Subagents inside one process | Team lead + teammates | Graph-based state machine | Role-based agents | Feudal hierarchy via tmux |
| **Parallelism** | Sequential (one at a time) | Multiple independent sessions | Parallel nodes (v0.2+) | Limited | **N independent agents** |
| **Coordination cost** | API calls per Task | Token-heavy (each teammate = separate context) | API + infra (Postgres/Redis) | API + CrewAI platform | **Zero** (YAML + tmux) |
| **External AI** | None | None | Custom integrations | Custom integrations | **Gemini + Codex via messengers** |
| **Observability** | Claude logs only | tmux split-panes or in-process | LangSmith integration | OpenTelemetry | **Live tmux panes** + dashboard |
| **Skill discovery** | None | None | None | None | **Bottom-up auto-proposal** |
| **Context safety** | None | None | None | None | **Hook-based role enforcement** |
| **Setup** | Built into Claude Code | Built-in (experimental) | Heavy (infra required) | pip install | Shell scripts |

### What makes this different

**Zero coordination overhead** — Agents talk through YAML files on disk. The only API calls are for actual work, not orchestration. Run N agents and pay only for N agents' work.

**Full transparency** — Every agent runs in a visible tmux pane. Every instruction, report, and decision is a plain YAML file you can read, diff, and version-control. No black boxes.

**Battle-tested hierarchy** — The Shogun → Karo → Ashigaru chain of command prevents conflicts by design: clear ownership, dedicated files per agent, event-driven communication, no polling.

**Multi-model orchestration** — Claude (Opus/Sonnet/Haiku), Gemini, and Codex work together. Each model is deployed where its strengths matter most. External agents are always summoned via Denrei (messengers), keeping the command chain responsive.

**Hook-based security** — Every agent is constrained by role-specific Claude Code PreToolUse hooks. Shogun can't write code. Ashigaru can't touch system config. Enforced at the tool call level, not by convention.

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

### Multi-Model Orchestration

Bakuhu orchestrates three different AI models, each deployed where its strengths matter most:

| Model | Used by | Role | Key Strength |
|-------|---------|------|-------------|
| **Claude Code** (Opus/Sonnet/Haiku) | Shogun, Karo, Ashigaru, Denrei | Core agents — full tmux hierarchy | Battle-tested integration, Memory MCP, dedicated file tools |
| **Gemini CLI** | Shinobi (忍び) | External intelligence | 1M token context, web search, PDF/video analysis |
| **Codex CLI** | Kyakusho (客将) | External strategic advisor | Deep reasoning, design decisions, code review |

External agents (Gemini/Codex) are **always summoned via Denrei** — never directly. This keeps the command chain responsive while the Denrei handles blocking API calls.

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

## Quick Start (Detailed)

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
| Claude Code CLI | `curl -fsSL https://claude.ai/install.sh \| bash` | Official Anthropic CLI (native version recommended) |

</details>

---

### After Setup

**Multiple AI agents** are automatically launched:

| Agent | Role | Count |
|-------|------|-------|
| 🏯 Shogun | Supreme commander — receives your orders | 1 |
| 📋 Karo | Manager — distributes tasks, maintains dashboard | 1 |
| ⚔️ Ashigaru | Workers — execute implementation tasks in parallel | 2 |
| 📨 Denrei | Messengers — summon and relay with external agents | 1 |
| 🎯 Gunshi | Quality Controller — QC review, routes complex tasks to Opus | 1 |

Two tmux sessions are created:
- `shogun` — connect here to give commands
- `multiagent` — Karo, Ashigaru, Denrei, and Gunshi running in the background

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

Meanwhile, the Karo distributes tasks to Ashigaru workers for parallel execution. If deep research is needed, Karo dispatches Denrei to summon Shinobi (Gemini).

### Step 3: Check progress

Open `dashboard.md` in your editor for a real-time status view:

```markdown
## In Progress
| Worker | Task | Status |
|--------|------|--------|
| Ashigaru 1 | Research React | Running |
| Ashigaru 2 | Research Vue | Running |
| Denrei 1 → Shinobi | Web search: Angular trends | Running |
| Ashigaru 3 | Research Svelte | Completed |
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
| Denrei 1 → Shinobi | Web search: Memory MCP + Sequential Thinking MCP |

All agents research simultaneously. Results appear in `dashboard.md` as they complete.

---

## Key Features

### ⚡ 1. Parallel Execution

One command spawns multiple parallel tasks:

```
You: "Research 5 MCP servers"
→ Multiple Ashigaru start researching simultaneously
→ Denrei summons Shinobi for deeper web research
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

### 📡 4. Event-Driven Communication (Zero Polling)

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

**Key design choices:**
- **Message content is never sent through tmux** — only a short "you have mail" nudge. The agent reads its own file. This eliminates character corruption and transmission hangs.
- **Zero CPU while idle** — `inotifywait` blocks on a kernel event (not a poll loop). CPU usage is 0% between messages.
- **Guaranteed delivery** — If the file write succeeded, the message is there. No lost messages, no retries needed.

**3-Phase Escalation** — If agent doesn't respond to nudge:

| Phase | Timing | Action |
|-------|--------|--------|
| Phase 1 | 0-2 min | Standard nudge (`inbox3` text + Enter) |
| Phase 2 | 2-4 min | Escape×2 + C-c to reset cursor, then nudge |
| Phase 3 | 4+ min | Send `/clear` to force session reset (max once per 5 min) |

### 📊 5. Agent Status Check

See which agents are busy or idle — instantly, from one command:

```bash
# Check current agent states from tmux pane content
tmux capture-pane -t multiagent:agents.0 -p | tail -5   # karo
tmux capture-pane -t multiagent:agents.1 -p | tail -5   # ashigaru1
```

Task status is visible via `dashboard.md` which the Karo maintains in real time:

```markdown
## In Progress
| Worker | Task | Status |
|--------|------|--------|
| ashigaru1 | subtask_042a_research | assigned |
| ashigaru2 | subtask_042b_review | done |
| denrei1 | summon_shinobi_042c | assigned |
```

### 📸 6. Screenshot Integration

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

### 📁 7. Context Management (4-Layer Architecture)

Efficient knowledge sharing through a four-layer context system:

| Layer | Location | Purpose |
|-------|----------|---------|
| Layer 1: Memory MCP | `memory/shogun_memory.jsonl` | Cross-project, cross-session long-term memory |
| Layer 2: Project | `config/projects.yaml`, `context/{project}.md` | Project-specific information and technical knowledge |
| Layer 3: YAML Queue | `queue/shogun_to_karo.yaml`, `queue/tasks/`, `queue/reports/` | Task management — source of truth for instructions and reports |
| Layer 4: Session | CLAUDE.md, instructions/*.md | Working context (wiped by `/clear`) |

This design enables:
- Any Ashigaru can work on any project
- Context persists across agent switches
- Clear separation of concerns
- Knowledge survives across sessions

#### /clear Protocol (Cost Optimization)

As agents work, their session context (Layer 4) grows, increasing API costs. `/clear` wipes session memory and resets costs. Layers 1–3 persist as files, so nothing is lost.

Recovery cost after `/clear`: **~1,950 tokens** (39% of the 5,000-token target — minimal boot sequence by design)

1. CLAUDE.md (auto-loaded) → recognizes itself as part of the system
2. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` → identifies its own number
3. Memory MCP read → restores the Lord's preferences (~700 tokens)
4. Task YAML read → picks up the next assignment (~800 tokens)

The key insight: designing **what not to load** is what drives cost savings.

### 📱 8. Phone Notifications (ntfy)

Two-way communication between your phone and the Shogun — no SSH, no Tailscale, no server needed.

| Direction | How it works |
|-----------|-------------|
| **Phone → Shogun** | Send a message from the ntfy app → `ntfy_listener.sh` receives it → Shogun processes automatically |
| **Karo → Phone (direct)** | When Karo updates `dashboard.md`, it sends push notifications via `scripts/ntfy.sh` — **Shogun is bypassed** |

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

Free, no account required, no server to maintain. Uses [ntfy.sh](https://ntfy.sh) — an open-source push notification service.

> **⚠️ Security:** Your topic name is your password. Choose a hard-to-guess name and **never share it publicly**.

### 🖼️ 9. Pane Border Task Display

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

### 🔊 10. Shout Mode (Battle Cries)

When an Ashigaru completes a task, it shouts a personalized battle cry in the tmux pane — a visual reminder that your army is working hard.

```
┌ ashigaru1 (Sonnet) ──────────┬ ashigaru2 (Sonnet) ──────────┐
│                               │                               │
│  ⚔️ 足軽1号、先陣切った！     │  🔥 足軽2号、二番槍の意地！   │
│  八刃一志！                   │  八刃一志！                   │
│  ❯                            │  ❯                            │
└───────────────────────────────┴───────────────────────────────┘
```

The Karo writes an `echo_message` field in each task YAML. After completing all work, the Ashigaru runs `echo` as its **final action**.

**Shout mode is the default.** To disable:

```bash
./shutsujin_departure.sh --silent    # No battle cries
./shutsujin_departure.sh             # Default: shout mode (battle cries enabled)
```

---

## 🥷 External Agents — Bakuhu Exclusive

The Shogun can summon external specialists **via Denrei (messengers)** for tasks that require capabilities beyond Claude Code:

| Agent | Tool | Role | Strengths |
|-------|------|------|-----------|
| **Shinobi (忍び)** | Gemini CLI | Intelligence & Research | 1M token context, Web search, PDF/video analysis |
| **Kyakusho (客将)** | Codex CLI | Strategic Advisor | Deep reasoning, Design decisions, Code review |

**Requirements:**
- **Shinobi**: Requires [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed separately
- **Kyakusho**: Requires [Codex CLI](https://github.com/openai/codex) installed separately

**Key rules:**
- Shogun/Karo summon external agents **only via Denrei** (forbidden action if done directly)
- Denrei handle the blocking API calls, keeping the command chain responsive
- Ashigaru can summon with explicit permission (`shinobi_allowed: true` in task YAML)

**Why Denrei (messengers)?**

External CLI tools (Gemini, Codex) block the terminal while running. If Karo called them directly, the entire command chain would freeze. Denrei are dedicated panes that absorb this blocking cost — so Karo stays responsive for other tasks.

```
Without Denrei:           With Denrei:
Karo → calls Gemini       Karo → Denrei 1 → Gemini (blocking)
Karo FROZEN 30s           Karo FREE (assigns other tasks)
                          Denrei 1 reports back when done
```

---

## 🛡️ Context Health Management — Bakuhu Exclusive

Long-running agents accumulate context, driving up API costs. Bakuhu manages this with built-in strategies:

### Context Usage Thresholds

| Status | Usage | Recommended Action |
|--------|-------|-------------------|
| 🟢 Healthy | 0-60% | Continue normal work |
| 🟡 Warning | 60-70% | /compact after current task (run_compact.sh) |
| 🔴 Danger | 70-80% | /compact immediately — no grace period |
| ⚫ Critical | 80%+ | /compact first; if no improvement, /clear |

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

## 🗣️ SayTask — Task Management for People Who Hate Task Management

> **⚠️ Status: Planned / Coming Soon** — SayTask is not yet implemented. Only `saytask/streaks.yaml.sample` exists as a placeholder. The design below describes the intended behavior.

### What is SayTask? (Planned)

**Task management for people who hate task management. Just speak to your phone.**

**Talk Coding, not Vibe Coding.** Speak your tasks, AI organizes them. No typing, no opening apps, no friction.

- **Target audience**: People who installed Todoist but stopped opening it after 3 days
- Your enemy isn't other apps — it's doing nothing. The competition is inaction, not another productivity tool
- Zero UI. Zero typing. Zero app-opening. Just talk

### Planned Design

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

### SayTask vs cmd Pipeline

Bakuhu has two complementary task systems (SayTask is planned, not yet implemented):

| Capability | SayTask (Voice Layer) | cmd Pipeline (AI Execution) |
|---|:-:|:-:|
| Voice input → task creation | 🔜 planned | — |
| Morning notification digest | 🔜 planned | — |
| Eat the Frog 🐸 selection | 🔜 planned | — |
| Streak tracking | 🔜 planned | 🔜 planned |
| AI-executed tasks (multi-step) | — | ✅ |
| Multiple-agent parallel execution | — | ✅ |

SayTask handles personal productivity (capture → schedule → remind). The cmd pipeline handles complex work (research, code, multi-step tasks).

---

## Architecture

### Agent Roles

| Agent | Role | Model | Count |
|-------|------|-------|-------|
| **Shogun (将軍)** | Commander — receives your orders, delegates to Karo | Opus | 1 |
| **Karo (家老)** | Steward — breaks tasks down, assigns to Ashigaru, maintains dashboard | Opus | 1 |
| **Ashigaru (足軽)** | Foot soldiers — execute tasks in parallel | Sonnet/Opus | 2 |
| **Denrei (伝令)** | Messengers — summon and relay with external agents | Haiku | 1 |
| **Gunshi (軍師)** | Quality Controller — QC review of all Ashigaru output, routes L4+ tasks | Sonnet | 1 |
| **Shinobi (忍び)** | Intelligence — research, web search, large document analysis | Gemini | External |
| **Kyakusho (客将)** | Strategist — deep reasoning, code review, design decisions | Codex | External |

### Agent Team (Claude Code Sub-agents / Agent SDK)

Separate from the tmux hierarchy, Bakuhu uses **Claude Code's native Agent Team feature** for complex development tasks requiring orchestration. These agents run as sub-processes within Claude Code, not as tmux panes.

Agent definitions live in `agents/default/` (following the Claude Agent SDK structure — `agent.yaml` + `system.md`, ported from upstream [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun)) and can be extended to support additional Agent SDK-compatible runtimes.

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| **Bugyo (奉行)** | Task Commander — breaks down tasks, coordinates team, validates quality. Never writes code directly; delegates to Ashigaru | inherit | All (delegate mode) |
| **Ashigaru (足軽)** | Implementation Worker — writes code, runs tests, debugs. Quality standard: `ruff check + format + pytest` | Sonnet | All |
| **Goikenban (御意見番)** | Code Reviewer — identifies problems, security risks, edge cases. Read-only (no Write/Edit access). Reports in 3 levels: Critical / Warning / Suggestion | Sonnet | Read, Grep, Glob, Bash |
| **Metsuke (目付)** | UI Inspector — opens pages in a real browser, takes screenshots, verifies clicks/transitions/playback. Read-only, confirms and reports only | Sonnet | Browser (Playwright), Read, Grep, Glob |

**Workflow:**
1. Bugyo receives task → decomposes into subtasks → creates TaskList
2. Bugyo spawns Ashigaru (implementation) and Goikenban (review) via Task tool
3. Ashigaru execute assigned tasks in parallel
4. Goikenban reviews all changes after implementation complete
5. If Critical issues found → Ashigaru fix → re-review cycle
6. Once all Critical issues resolved → Bugyo reports completion

**Key difference from tmux agents:**
- **tmux agents** (Shogun/Karo/Ashigaru/Denrei): Long-lived, coordinated via YAML files, visible in tmux panes
- **Agent Team**: Short-lived, spawned on-demand for specific tasks, coordinated via Claude Code's Task/SendMessage tools, exist only for task duration

### Communication Protocol

- **Downward** (orders): Write YAML → wake target with `tmux send-keys` (or mailbox system)
- **Upward** (reports): Write YAML only (no send-keys to avoid interrupting your input)
- **External agents**: Always summoned via Denrei (never directly)
- **Polling**: Forbidden. Event-driven only. Your API bill stays predictable.

### North Star (cmd Direction)

Every command issued by Shogun **must include a `north_star` field** — a 1-2 sentence statement explaining how this specific command contributes to the project's business objectives.

```yaml
# queue/shogun_to_karo.yaml
cmd_id: cmd_462
project: bakuhu
north_star: >
  Establish context/{project}.md as the authoritative source for project goals,
  ensuring every cmd is anchored to measurable business outcomes.
purpose: "Create bakuhu.md context file for the bakuhu project"
```

`north_star` is derived from `context/{project}.md`'s North Star section — the project's guiding purpose. When agents face judgment calls (prioritization, scope decisions, tradeoffs), they check `north_star` first.

**North star quality criteria:**
- ✅ **Good**: "Prevent Shogun reflexive actions by structuring all cmd decisions around business goals"
- ❌ **Bad**: "Make the system better" ← too abstract, useless as a decision anchor

**Why this matters:** Without it, agents optimize locally (finish the task) rather than globally (advance the project). A technically correct implementation that doesn't serve the business goal is waste.

### 🔒 Identity Isolation v3 (Role-Based Access Control)

Bakuhu enforces role boundaries through **Claude Code PreToolUse hooks**. Each agent can only take actions appropriate to its role — enforced at the tool call level, not by convention.

#### Identity resolution

Every agent's identity is resolved from its **tmux pane ID** via `config/pane_role_map.yaml` — never from MEMORY.md or any user-writable variable. This prevents identity contamination across sessions.

```
Session startup (shutsujin_departure.sh)
    ↓
Generates pane_role_map.yaml: { %0: shogun, %1: karo, %2: ashigaru, ... }
Records sha256sum → pane_role_map.yaml.sha256
Sets hook_common.sh to read-only (chmod 444)
    ↓
Every tool call (PreToolUse hook):
    get_role() → tmux pane ID → pane_role_map.yaml → role
    Apply role-specific restrictions → exit 0 (allow) or exit 2 (deny)
```

#### Two-layer hook protection

Each role has two dedicated hooks: a **Bash execution guard** and a **file write guard**.

| Hook | What it prevents |
|------|----------------|
| `shogun-guard.sh` / `shogun-write-guard.sh` | Shogun reading/editing source code (delegates only) |
| `karo-guard.sh` / `karo-write-guard.sh` | Karo running implementation commands (python, pytest, npm, ruff) |
| `ashigaru-write-guard.sh` | Ashigaru editing system config, instructions, or other roles' memory |
| `denrei-write-guard.sh` | Denrei writing source code (messenger stays in its lane) |
| `global-guard.sh` | **All roles**: destructive operations (rm -rf, git push --force, sudo, kill, curl\|bash, etc.) |

#### Memory separation

Each role has a dedicated memory file. Cross-role writes are blocked at the hook level.

| Role | Memory file | Write access |
|------|-------------|-------------|
| Shogun | `memory/shogun.md` | Shogun only |
| Karo | `memory/karo.md` | Karo only |
| Ashigaru | `memory/ashigaru.md` | Ashigaru only |
| Denrei | `memory/denrei.md` | Denrei only |

`MEMORY.md` (auto-injected into all sessions) contains **only a lookup table** mapping roles to their memory files. No identity information is stored there.

#### Startup self-test

`scripts/selftest_hooks.sh` verifies the hook system at session startup:
- All hook files exist with correct execute permissions
- SHA-256 integrity of `hook_common.sh` (the shared hook library)
- JSON Schema validation of all policy YAML files
- Zero-tolerance: any failure blocks the session

### Design Philosophy

#### Why a hierarchy (Shogun → Karo → Ashigaru)?

1. **Instant response**: The Shogun delegates immediately, returning control to you
2. **Parallel execution**: The Karo distributes to multiple Ashigaru simultaneously
3. **Single responsibility**: Each role is clearly separated — no confusion
4. **Scalability**: Adding more Ashigaru doesn't break the structure
5. **Fault isolation**: One Ashigaru failing doesn't affect the others
6. **Unified reporting**: Only the Shogun communicates with you, keeping information organized

#### Why Mailbox System?

| Problem with direct messaging | How mailbox solves it |
|-------------------------------|----------------------|
| Agent crashes → message lost | YAML files survive restarts |
| Polling wastes API calls | `inotifywait` is event-driven (zero CPU while idle) |
| Agents interrupt each other | Each agent has its own inbox file — no cross-talk |
| Hard to debug | Open any `.yaml` file to see exact message history |
| Concurrent writes corrupt data | `flock` (exclusive lock) serializes writes automatically |
| Delivery failures | Message content stays in files — only a short nudge is sent through tmux |

#### Why only the Karo updates dashboard.md

1. **Single writer**: Prevents conflicts by limiting updates to one agent
2. **Information aggregation**: The Karo receives all Ashigaru reports, so it has the full picture
3. **Consistency**: All updates pass through a single quality gate
4. **No interruptions**: If the Shogun updated it, it could interrupt the Lord's input

---

## Model Settings

| Agent | Default Model | Thinking | Role |
|-------|--------------|----------|------|
| Shogun | Opus | **Enabled (high)** | Strategic advisor to the Lord. Use `--shogun-no-thinking` for relay-only mode |
| Karo | Opus | Enabled | Task distribution, bloom_routing, dashboard management |
| Ashigaru 1–2 | Sonnet | Enabled | Implementation: code, research, file operations (L1–L3 tasks) |
| Denrei 1 | Haiku | Disabled | Relay tasks only — stateless messenger |
| Gunshi | Sonnet | Enabled | QC review of all Ashigaru output. L4–L6 tasks routed here |

### Battle Formations

| Formation | Ashigaru 1–N | Command |
|-----------|-------------|---------|
| **Normal** (default) | Sonnet | `./shutsujin_departure.sh` |
| **Battle** (`-k` flag) | Opus | `./shutsujin_departure.sh -k` |

By default, Ashigaru run on the cheaper Sonnet model. When it's crunch time, switch to Battle formation with `-k` (`--kessen`) for all-Opus maximum capability.

### Bloom Routing (Dynamic Model Selection)

Karo automatically routes tasks to the right model based on **Bloom's Taxonomy** complexity level (L1–L6):

| Bloom Level | Complexity | Model | Agent |
|-------------|-----------|-------|-------|
| L1–L3 | Remember / Understand / Apply | Sonnet | Ashigaru |
| L4–L6 | Analyze / Evaluate / Create | Opus | Gunshi |

```yaml
# In task YAML
bloom_level: L5   # → Karo routes to Gunshi (Opus) automatically
```

- **L1 (Remember)**: Retrieve facts, find a file, check a value
- **L2 (Understand)**: Explain code, summarize a report
- **L3 (Apply)**: Write a function, fix a known bug
- **L4 (Analyze)**: Diagnose root cause, compare approaches
- **L5 (Evaluate)**: Design review, architectural judgment
- **L6 (Create)**: Design a new system, write a spec from scratch

Configured in `config/settings.yaml` → `bloom_routing: auto`.

### Task Dependencies (blockedBy)

Tasks can declare dependencies on other tasks using `blockedBy`:

```yaml
# queue/tasks/ashigaru2.yaml
task:
  task_id: subtask_010b
  blockedBy: ["subtask_010a"]  # Waits for ashigaru1's task to complete
  description: "Integrate the API client built by subtask_010a"
```

When a blocking task completes, the Karo automatically unblocks dependent tasks and assigns them to available Ashigaru.

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
| **Triangulation** | Multi-perspective research — Claude, Gemini, and Codex each bring different lenses |

---

## Skills

No skills are included out of the box. Skills emerge organically during operation — you approve candidates from `dashboard.md` as they're discovered.

Invoke skills with `/skill-name`. Just tell the Shogun: "run /skill-name".

### Skill System

The `skills/` directory contains a growing library of modular knowledge files that agents load on demand. These are **reference documents, not slash commands** — agents read them to gain domain expertise.

**Built-in skill files include:**

| Skill File | Purpose |
|-----------|---------|
| `bloom-routing.md` | Bloom Taxonomy L1–L6 model routing rules |
| `context-health.md` | /compact templates, mixed strategies |
| `identity-management.md` | Identity isolation design, tmux pane resolution |
| `shinobi-manual.md` | Shinobi (Gemini) capabilities and summon protocol |
| `spec-before-action.md` | Spec-first principle (all agents must read) |
| `bugyo-workflow.md` | Agent Team (Bugyo) orchestration workflow |
| `karo-workflow-steps.md` | Karo step-by-step workflow reference |
| `ashigaru-workflow-steps.md` | Ashigaru detailed workflow steps |
| `external-agent-rules.md` | External agent (Shinobi/Kyakusho) summon rules |
| `skill-candidate-flow.md` | How to propose and promote new skills |

**Shogun convenience skills** (structured directories in `skills/`, ported from upstream [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun)):

| Skill | What it does |
|-------|-------------|
| `shogun-agent-status/` | Check all agent status from one command |
| `shogun-bloom-config/` | Configure Bloom routing settings |
| `shogun-model-list/` | List available models per agent |
| `shogun-model-switch/` | Switch agent model mid-operation |
| `shogun-readme-sync/` | Sync README with latest changes |
| `shogun-screenshot/` | Capture and analyze screenshots (includes Python helper) |

### Skill Philosophy

**1. Skills are not committed to the repo**

User-created skills in `.claude/commands/` are excluded from version control by design:
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

## Testing

> Ported from upstream [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun).

Bakuhu ships with a comprehensive test suite covering both system behavior and agent coordination.

### E2E Test Framework (`tests/e2e/`)

End-to-end tests use **bats** (Bash Automated Testing System) with a mock CLI layer that simulates agent behavior without real API calls:

| Test Suite | What it covers |
|-----------|----------------|
| `e2e_basic_flow.bats` | Basic Shogun → Karo → Ashigaru command flow |
| `e2e_parallel_tasks.bats` | Multiple Ashigaru executing in parallel |
| `e2e_bloom_routing.bats` | Automatic model routing via Bloom Taxonomy |
| `e2e_inbox_delivery.bats` | Mailbox system message delivery |
| `e2e_escalation.bats` | 3-phase escalation (nudge → escape → /clear) |
| `e2e_redo.bats` | Task redo protocol with session reset |
| `e2e_clear_recovery.bats` | Agent recovery after /clear |
| `e2e_blocked_by.bats` | Task dependency (blockedBy) unblocking |
| `e2e_codex_startup.bats` | Codex CLI (Kyakusho) startup sequence |

The mock CLI (`tests/e2e/mock_cli.sh`) intercepts `claude`, `gemini`, and `codex` commands. Agent behavior is defined in `tests/e2e/mock_behaviors/`.

### Unit Tests (`tests/unit/`)

| Test | What it covers |
|------|----------------|
| `test_dynamic_model_routing.bats` | Bloom routing decision logic |
| `test_inbox_write.bats` | inbox_write.sh correctness and flock behavior |
| `test_idle_flag.bats` | Agent idle flag set/clear lifecycle |
| `test_ntfy_ack.bats` | ntfy acknowledgment flow |
| `test_stop_hook.bats` | PreToolUse hook blocking behavior |
| `test_switch_cli.bats` | CLI switching (claude ↔ codex ↔ gemini) |
| `test_build_system.bats` | Build system correctness |

### Running Tests

```bash
# Run all E2E tests
bats tests/e2e/

# Run all unit tests
bats tests/unit/

# Run a specific suite
bats tests/e2e/e2e_basic_flow.bats
```

---

## Android App

> Ported from upstream [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun).

Bakuhu includes a native Android app for mobile command and monitoring — beyond the SSH/Termux approach.

### Features

- **Native Kotlin + Jetpack Compose** — modern Android architecture
- **SSH connection to tmux** — connects directly to your running Bakuhu session
- **ntfy notification integration** — real-time push notifications when tasks complete
- **5-screen interface**: Agent grid, dashboard view, command input, settings, rate-limit status

### Screenshots

| Shogun Terminal | Agent Grid | Dashboard | Settings | Rate Limit |
|:-:|:-:|:-:|:-:|:-:|
| ![Shogun](android/screenshots/01_shogun_terminal.png) | ![Agents](android/screenshots/02_agents_grid.png) | ![Dashboard](android/screenshots/03_dashboard.png) | ![Settings](android/screenshots/04_settings.png) | ![Rate](android/screenshots/05_ratelimit.png) |

### Installation

Pre-built APKs are available in `android/release/`. Sideload onto your Android device:

1. Enable "Install from unknown sources" in Android settings
2. Transfer the APK to your phone
3. Install and configure with your Tailscale IP and SSH credentials

---

## MCP Setup Guide

MCP (Model Context Protocol) servers extend Claude's capabilities. Here's how to set them up:

### What is MCP?

MCP servers give Claude access to external tools:
- **Notion MCP** → Read and write Notion pages
- **GitHub MCP** → Create PRs, manage issues
- **Memory MCP** → Persist memory across sessions
- **Playwright MCP** → Browser automation (used by Metsuke for UI inspection)

### Installing MCP Servers

Add MCP servers with these commands:

```bash
# 1. Notion - Connect to your Notion workspace
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - Browser automation (required for Metsuke UI inspector)
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
   - Denrei 1 → Shinobi: Deep research via Gemini (web search + PDF analysis)
3. All agents research simultaneously
4. Results compiled in dashboard.md
```

### Example 2: PoC preparation with external intelligence

```
You: "Prepare a PoC for the project on this Notion page: [URL]"

What happens:
1. Karo fetches Notion content via MCP
2. Ashigaru 2: Lists items to verify
3. Ashigaru 3: Investigates technical feasibility
4. Denrei + Shinobi: Deep research on unfamiliar tech (1M context window)
5. Denrei + Kyakusho: Architecture review and design recommendations
6. All results compiled in dashboard.md — meeting prep done
```

### Example 3: Full-stack feature with review

```
You: "Add a REST API endpoint for user authentication with tests"

What happens:
1. Karo dispatches Bugyo (Agent Team mode)
2. Bugyo decomposes: spec → implementation → tests → review
3. Ashigaru implements the feature
4. Goikenban reviews: security risks, edge cases, completeness
5. If Critical issues found → fix → re-review
6. Metsuke verifies UI integration in browser
7. Bugyo reports completion
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

### External agents

```yaml
# config/settings.yaml
external_agents:
  shinobi: true    # Enable Gemini CLI integration
  kyakusho: true   # Enable Codex CLI integration
```

Requires Gemini CLI and/or Codex CLI installed separately.

---

## Advanced

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

# Shogun relay-only mode: Disable Shogun's thinking (cost savings)
./shutsujin_departure.sh --shogun-no-thinking

# Show help
./shutsujin_departure.sh -h
./shutsujin_departure.sh --help
```

</details>

<details>
<summary><b>Context Health Check Commands</b> (click to expand)</summary>

```bash
# Check Karo's context usage (run from Shogun)
bash scripts/check_context.sh karo

# Check specific Ashigaru
bash scripts/check_context.sh ashigaru1

# Run compact on an agent (via script, not direct)
bash scripts/run_compact.sh karo
bash scripts/run_compact.sh ashigaru1
```

**Important:** Context measurement must be done externally (Shogun measures Karo, Karo measures Ashigaru). Self-measurement is inaccurate.

</details>

---

## File Structure

<details>
<summary><b>Click to expand file structure</b></summary>

```
multi-agent-bakuhu/
│
│  ┌──────────────── Setup Scripts ──────────────────┐
├── first_setup.sh            # First-time setup (config, dependencies, MCP)
├── shutsujin_departure.sh    # Daily deployment (auto-loads instructions)
│  └─────────────────────────────────────────────────┘
│
├── instructions/             # Agent instruction files
│   ├── shogun.md             # Shogun (strategic advisor)
│   ├── karo.md               # Karo (chief of staff)
│   ├── ashigaru.md           # Ashigaru (implementation workers)
│   ├── kyakusho.md           # Kyakusho (guest general: Codex CLI)
│   ├── shinobi.md            # Shinobi (scout: Gemini)
│   ├── denrei.md             # Denrei (messenger)
│   ├── metsuke.md            # Metsuke (UI inspector: Playwright)
│   ├── cli_specific/         # CLI-specific tool descriptions
│   └── generated/            # CLI-variant instructions (Codex/Copilot/Kimi etc.)
│                              # Not used in bakuhu (Claude Code only)
│                              # Sync when adding other CLIs; upstream-derived, do not edit
│
├── scripts/                  # Utility scripts
│   ├── inbox_write.sh        # Write messages to agent inbox
│   ├── inbox_watcher.sh      # Watch inbox changes via inotifywait
│   ├── check_context.sh      # Measure agent context usage (run externally)
│   ├── run_compact.sh        # Trigger /compact on an agent
│   ├── ntfy.sh               # Send push notifications to phone
│   ├── ntfy_listener.sh      # Stream incoming messages from phone
│   ├── agent_status.sh       # Check all agent states at once
│   ├── switch_cli.sh         # Switch active CLI (claude/codex/gemini)
│   ├── ratelimit_check.sh    # Check API rate limit status
│   └── kill_playwright.sh    # Stop Playwright MCP processes
│
├── config/
│   ├── settings.yaml         # Language, ntfy, agent settings
│   └── projects.yaml         # Project registry
│
├── context/                  # Project North Star files (referenced in cmd YAML)
│   └── {project}.md          # Per-project purpose, business context, north_star
│
├── queue/                    # Communication and task files
│   ├── shogun_to_karo.yaml   # Shogun → Karo commands
│   ├── inbox/                # Per-agent inbox files
│   │   ├── karo.yaml
│   │   └── ashigaru{1-N}.yaml
│   ├── tasks/                # Per-worker task YAML files
│   ├── reports/              # Worker report YAML files
│   ├── kyakusho/             # Kyakusho (Codex) task queue
│   ├── shinobi/              # Shinobi (Gemini) task queue
│   ├── denrei/               # Denrei task queue
│   └── 殿/                   # Lord's reports and documents
│
├── skills/                   # Modular knowledge files (agents load on demand)
│   ├── bloom-routing.md      # Bloom Taxonomy L1-L6 model routing
│   ├── context-health.md     # /compact templates, mixed strategies
│   ├── identity-management.md# Identity isolation design
│   ├── spec-before-action.md # Spec-first principle (all agents must read)
│   ├── shinobi-manual.md     # Shinobi (Gemini) capabilities & protocol
│   ├── shogun-agent-status/  # Agent status check skill
│   ├── shogun-screenshot/    # Screenshot capture skill (Python helper)
│   └── generated/            # Dev project skills (git-ignored)
│
├── tests/                    # Test suite
│   ├── e2e/                  # End-to-end tests (bats + mock CLI)
│   │   ├── mock_cli.sh       # Mock for claude/codex/gemini commands
│   │   ├── mock_behaviors/   # Per-CLI mock behavior definitions
│   │   ├── fixtures/         # Test fixtures
│   │   └── helpers/          # Test helpers (assertions, tmux, setup)
│   └── unit/                 # Unit tests (bats)
│
├── android/                  # Android app (Kotlin + Jetpack Compose)
│   ├── app/                  # App source code
│   ├── release/              # Pre-built APKs
│   └── screenshots/          # App screenshots
│
├── agents/                   # Agent SDK definitions
│   └── default/              # Default agent (agent.yaml + system.md)
│
├── .claude/                  # Claude Code configuration
│   ├── hooks/                # Pre/post tool hooks (gitignore guardian, etc.)
│   ├── agents/               # Sub-agent definitions (bugyo, goikenban, etc.)
│   ├── rules/                # Project rules (auto-loaded per directory)
│   └── commands/             # Slash commands
│
├── logs/                     # Agent log files
├── memory/                   # Memory MCP persistent storage
├── projects/                 # Project details (git-ignored, may contain secrets)
├── dashboard.md              # Real-time status board (Karo maintains)
└── CLAUDE.md                 # System instructions (auto-loaded by Claude Code)
```

</details>

---

## Troubleshooting

<details>
<summary><b>Agent not responding to inbox messages</b></summary>

The inbox_watcher escalation system handles this automatically:

| Elapsed | Action |
|---------|--------|
| 0–2 min | Standard `tmux send-keys` nudge |
| 2–4 min | Escape×2 + nudge (cursor position bug workaround) |
| 4 min+ | `/clear` sent (force session reset, max once per 5 min) |

To manually check inbox delivery: `cat queue/inbox/{agent}.yaml`

</details>

<details>
<summary><b>Context overflow — agent running slow or refusing tasks</b></summary>

```bash
# Measure agent context (run externally — self-measurement is inaccurate)
bash scripts/check_context.sh karo
bash scripts/check_context.sh ashigaru1

# Trigger compact (Shogun triggers for Karo; Karo triggers for Ashigaru)
bash scripts/run_compact.sh karo
```

Thresholds: 60% → compact after current task; 85%+ → `/clear` immediately.

</details>

<details>
<summary><b>Hook blocking file operations unexpectedly</b></summary>

Hooks in `.claude/hooks/` enforce rules like `.gitignore` write protection. If a legitimate operation is blocked, request Lord's (殿's) explicit permission. Do NOT bypass hooks without permission.

</details>

<details>
<summary><b>Identity contamination — agents claiming wrong role after restart</b></summary>

If agents all claim the same role:

```bash
# Check each agent's identity
tmux display-message -t multiagent:agents.0 -p '#{@agent_id}'  # karo
tmux display-message -t multiagent:agents.1 -p '#{@agent_id}'  # ashigaru1
```

Root cause: MEMORY.md or Memory MCP graph contained identity info (shared across all agents). Never write role/identity info to shared persistent storage. See CLAUDE.md Session Start procedure for recovery.

</details>

<details>
<summary><b>Playwright MCP tools not loading</b></summary>

Playwright MCP tools are lazy-loaded. If tools aren't available after `ToolSearch`, restart Claude Code. MCP is defined in `.mcp.json`.

</details>

---

## tmux Quick Reference

| Command | Description |
|---------|-------------|
| `tmux attach -t shogun` | Connect to Shogun session |
| `tmux attach -t multiagent` | Connect to multi-agent session |
| `Ctrl+B` then `0` | Karo pane |
| `Ctrl+B` then `1`–`N` | Ashigaru 1–N panes |
| `Ctrl+B` then `d` | Detach (agents keep running in background) |
| `Ctrl+B` then `[` | Enter scroll mode (Esc to exit) |

### Mouse Support

`first_setup.sh` configures `set -g mouse on` in `~/.tmux.conf`:

| Action | Description |
|--------|-------------|
| Mouse wheel | Scroll within a pane |
| Click a pane | Switch focus between panes |
| Drag pane border | Resize panes |

---

## Contributing

Issues and pull requests are welcome.

- **Bug reports**: Open an issue with reproduction steps
- **Feature ideas**: Open a discussion first
- **Skills**: Skills are personal by design (`skills/generated/` is git-ignored)
- **Development**: Fork → branch → PR against `main`

## Credits

- **Original**: [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa
- **Fork base**: [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) by yohey-w
- **This repo**: [multi-agent-bakuhu](https://github.com/yaziuma/multi-agent-bakuhu) — Bakuhu extensions: Context Health Management, Identity Isolation v3, External Agents (Shinobi/Kyakusho), North Star

## License

[MIT](LICENSE)
