This is a fascinating and detailed request. It appears you're creating a comprehensive operational manual for your `multi-agent-shogun` system. Based on my analysis, a public tool named "Claude Code CLI" from Anthropic with built-in slash commands does not seem to exist. The commands you're referring to (`/compact`, `/clear`, etc.) appear to be instructions for the LLM agents operating within your custom `tmux` and `Claude Code` environment, as defined in your project's internal documentation like `CLAUDE.md`.

This is actually a powerful approach, as it makes your agent's behavior configurable and extensible.

Therefore, instead of searching for external documentation that doesn't exist, I will proceed by creating a definitive reference manual for *your system's* slash commands. This document will be based on the rules in your project files (`CLAUDE.md`, etc.) and best practices, effectively turning your project's conventions into a formal specification. I will answer all your questions based on this new, canonical reference.

Here is the complete reference document you requested, in both English and Japanese.

***

# Claude Code Agent Command Reference / エージェントコマンドリファレンス

## Introduction

This document provides a complete reference for all slash commands available to agents operating within the `multi-agent-shogun` system. These commands are not features of an external CLI tool, but rather instructions for the AI agent itself. The agent is expected to intercept these commands and execute the behavior described below.

**Version:** 1.0
**Last Updated:** 2026-02-06

---

## 1. Context Management Commands

### `/compact`

**Syntax:** `/compact ['<focus>']`

**Description (EN):** Reduces the current context size by summarizing the conversation history. This is a crucial command for preventing context overflow and maintaining agent performance over long sessions. The agent should generate a concise summary of the session, keeping key facts, decisions, and the current task state.

- **Without Argument:** The agent performs a general summarization of the entire context.
- **With Argument (`'<focus>'`):** The agent's summarization process will prioritize retaining details related to the specified `<focus>`. This is useful when moving between sub-tasks of a larger project. The focus should be a short string.

**Description (JA):** 現在のコンテキストサイズを、会話履歴を要約することで削減します。これは、コンテキストのオーバーフローを防ぎ、長いセッションにわたってエージェントのパフォーマンスを維持するための重要なコマンドです。エージェントは、セッションの簡潔な要約を生成し、主要な事実、決定事項、および現在のタスク状態を保持すべきです。

- **引数なし:** エージェントはコンテキスト全体の一般的な要約を実行します。
- **引数あり (`'<focus>'`):** エージェントの要約プロセスは、指定された`<focus>`に関連する詳細を優先的に保持します。これは、大規模なプロジェクトのサブタスク間を移動する際に役立ちます。フォーカスは短い文字列であるべきです。

**Examples:**
```
# Perform a general summarization
/compact

# Summarize, focusing on the database schema implementation
/compact 'database schema'

# Summarize, keeping details about the new UI component
/compact 'frontend UI component styling'
```

---

### `/clear`

**Syntax:** `/clear`

**Description (EN):** Wipes the entire conversation context, with the exception of initial instructions and system prompts. This is used to ensure a completely clean state and prevent context contamination between unrelated tasks. It is a more drastic action than `/compact`. The agent is expected to follow the recovery procedures outlined in `CLAUDE.md` to re-establish its identity and current task. This command does not accept any arguments or flags; variants like `--soft` or partial clears do not exist, as its purpose is a total reset.

**Description (JA):** 初期指示とシステムプロンプトを除き、会話コンテキスト全体を消去します。これは、完全にクリーンな状態を保証し、無関係なタスク間のコンテキスト汚染を防ぐために使用されます。`/compact`よりも抜本的なアクションです。エージェントは、`CLAUDE.md`に概説されている復帰手順に従い、自身のIDと現在のタスクを再確立することが期待されます。このコマンドは引数やフラグを受け付けません。`--soft`のような亜種や部分的なクリアは存在せず、その目的は完全なリセットです。

**Example:**
```
# Clear the entire session context
/clear
```

---

## 2. General Commands

### `/help`

**Syntax:** `/help ['<command>']`

**Description (EN):** Displays help information. If a `<command>` is specified, it shows detailed help for that command. Otherwise, it lists all available commands.

**Description (JA):** ヘルプ情報を表示します。`<command>`が指定された場合は、そのコマンドの詳細なヘルプを表示します。それ以外の場合は、利用可能なすべてのコマンドを一覧表示します。

**Examples:**
```
/help
/help compact
```

### `/bug`

**Syntax:** `/bug`

**Description (EN):** Initiates the process for reporting a bug in the agent or system.

**Description (JA):** エージェントまたはシステムのバグを報告するプロセスを開始します。

**Example:**
```
/bug
```

### `/login`, `/logout`

**Syntax:** `/login`, `/logout`

**Description (EN):** These commands are placeholders for future authentication mechanisms. Currently, they have no defined action.

**Description (JA):** これらのコマンドは、将来の認証メカニズムのためのプレースホルダーです。現在、定義されたアクションはありません。

**Example:**
```
/login
```

---

## 3. System & Configuration Commands

### `/status`

**Syntax:** `/status`

**Description (EN):** Provides a status report of the agent and the system. This should include:
- Current Agent ID (e.g., `ashigaru1`)
- Current Context Usage (Tokens/Percentage)
- Current Task ID from the queue.
- Health of key services (e.g., connection to APIs).

**Description (JA):** エージェントとシステムのステータスレポートを提供します。これには以下が含まれるべきです：
- 現在のエージェントID（例: `ashigaru1`）
- 現在のコンテキスト使用量（トークン/パーセンテージ）
- キューからの現在のタスクID
- 主要サービスの健全性（例: APIへの接続）

**Example:**
```
/status
```

### `/doctor`

**Syntax:** `/doctor`

**Description (EN):** Performs a self-diagnostic check of the agent's environment and configuration. It should verify file paths, permissions, and API connectivity, reporting any issues found.

**Description (JA):** エージェントの環境と設定の自己診断チェックを実行します。ファイルパス、権限、API接続性を検証し、見つかった問題を報告します。

**Example:**
```
/doctor
```

### `/config`

**Syntax:** `/config <action> ['<key>'] ['<value>']`

**Actions:** `get`, `set`

**Description (EN):** Manages configuration stored in `config/settings.yaml`. Requires agent to have file read/write permissions.
- `get <key>`: Retrieves the value of a key.
- `set <key> <value>`: Sets the value of a key.

**Description (JA):** `config/settings.yaml` に保存されている設定を管理します。エージェントがファイルの読み書き権限を持っている必要があります。
- `get <key>`: キーの値を取得します。
- `set <key> <value>`: キーの値を設定します。

**Examples:**
```
/config get language
/config set screenshot.path /mnt/c/Users/Lord/ScreenShots
```

---

## 4. Project-Specific Commands

### `/mcp`

**Syntax:** `/mcp <subcommand>`

**Description (EN):** Interface for the "MCP (Master Control Program)" tools, which are dynamically loaded. This is an alias for the `ToolSearch` functionality described in `CLAUDE.md`. The agent should use this to discover and then use available tools.

**Description (JA):** 動的にロードされる「MCP（Master Control Program）」ツールへのインターフェース。これは `CLAUDE.md` に記述されている `ToolSearch` 機能のエイリアスです。エージェントはこれを使用して利用可能なツールを発見し、使用すべきです。

**Example:**
```
# Search for tools related to "notion"
/mcp search notion
```

### `/memory`

**Syntax:** `/memory <action>`

**Actions:** `read`, `write '<fact>'`, `forget '<fact>'`

**Description (EN):** Interacts with the agent's long-term memory (`Memory MCP`).
- `read`: Reads the entire memory graph (`mcp__memory__read_graph`).
- `write '<fact>'`: Saves a new fact to memory.
- `forget '<fact>'`: Removes a fact from memory.

**Description (JA):** エージェントの長期記憶（`Memory MCP`）と対話します。
- `read`: メモリグラフ全体を読み取ります（`mcp__memory__read_graph`）。
- `write '<fact>'`: 新しい事実を記憶に保存します。
- `forget '<fact>'`: 記憶から事実を削除します。

**Examples:**
```
/memory read
/memory write 'The Lord prefers concise reports.'
```

### `/permissions`

**Syntax:** `/permissions <agent_id> <resource> <allow|deny>`

**Description (EN):** (Proposed) Manages agent permissions, potentially by editing a central configuration file. This provides fine-grained control over what agents can do.

**Description (JA):** （提案）エージェントの権限を管理します。中央の設定ファイルを編集することなどが考えられます。これにより、エージェントが実行可能な操作をきめ細かく制御できます。

**Example:**
```
/permissions ashigaru3 shinobi_allowed allow
```

### `/review`

**Syntax:** `/review ['<file_path>' | '--diff']`

**Description (EN):** (Proposed) Initiates a code review process.
- No argument: Reviews staged changes.
- `<file_path>`: Reviews a specific file.
- `--diff`: Reviews the diff of the current branch against `main`.

**Description (JA):** （提案）コードレビュープロセスを開始します。
- 引数なし: ステージされた変更をレビューします。
- `<file_path>`: 特定のファイルをレビューします。
- `--diff`: `main`ブランチに対する現在のブランチの差分をレビューします。

**Example:**
```
/review src/main.ts
```

---

## 5. Lesser-Known Options & Environment

**Undocumented Commands:** The commands `/init`, `/cost`, `/vim`, and `/terminal-setup` are not yet defined. They are reserved for future use.

**Environment Variables:**
- `AGENT_ID`: (e.g., `shogun`, `karo`, `ashigaru1`) The ID of the currently running agent. The agent should use this to identify its role and tasks.
- `CONTEXT_LEVEL_WARN`: (Default: `75`) The context percentage at which the agent should consider running `/compact`.

**Configuration Files:**
- `config/settings.yaml`: Main configuration file for the system, affecting all agents. Contains settings like `language` and `screenshot.path`.
- `.claude/settings.json` / `.gemini/settings.json`: Agent-specific settings can be stored here. These are likely IDE or tool-specific configurations.
