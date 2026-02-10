### Section 4: Cost Analysis

A detailed cost comparison between `/clear` and `/compact` reveals significant differences in token consumption and context preservation, making each suitable for different scenarios.

#### 1. Token Cost Breakdown

*   **/clear Recovery Cost**: This approach involves a "cold start" for the agent's context. The cost is purely input tokens required to reload the foundational knowledge.
    *   `CLAUDE.md`: ~2000 tokens
    *   `Memory MCP read`: ~700 tokens
    *   `task YAML`: ~800 tokens
    *   `instructions/*.md`: ~1500 tokens
    *   **Total Recovery Cost**: **~5000 input tokens** per `/clear` cycle.

*   **/compact Cost**: This is a two-part cost involving summary generation (output) and subsequent use of that summary (input).
    *   **Output Cost**: The cost of generating the summary. This varies, but a reasonable estimate is **~750 output tokens**.
    *   **Input Cost**: For the next turn, the input starts with the summary itself (~750 tokens) instead of the full 5000-token reload.

*   **Comparison**: A single `/clear` cycle consumes a large number of input tokens (~5000). A single `/compact` cycle consumes fewer output tokens (~750) and leads to a much smaller initial input for the next turn, making it significantly more token-efficient per cycle.

#### 2. Simulation

Let's analyze an 8-hour workday where the agent hits context limits every 30 minutes, resulting in 16 total cycles.

*   **Scenario A: `/clear` every time**
    *   The agent performs a full context reload 16 times.
    *   Total Cost: `16 cycles × 5000 tokens/cycle` = **80,000 tokens**.
    *   Context Preservation: **None**. The agent effectively has amnesia every 30 minutes. It can only rely on external files (YAMLs, MCP) to recover its state, losing any "in-flight" reasoning or short-term memory.

*   **Scenario B: Mixed Strategy (`/compact` 3 times, then `/clear`)**
    *   This constitutes 4 complete sequences of (compact, compact, compact, clear).
    *   Total Compact Actions: `12`
    *   Total Clear Actions: `4`
    *   Compact Cost: `12 actions × 750 tokens/action` = 9,000 tokens.
    *   Clear Cost: `4 actions × 5000 tokens/action` = 20,000 tokens.
    *   Total Cost: `9,000 + 20,000` = **29,000 tokens**.
    *   Context Preservation: **High**. The agent maintains a summarized "train of thought" for 1.5 hours at a time. This allows it to handle longer, more complex tasks that span multiple 30-minute work cycles. The periodic `/clear` acts as a "garbage collection" to prevent summary bloat or corruption.

*   **Conclusion**: The mixed strategy (Scenario B) is nearly **3 times cheaper** and provides vastly superior context preservation, making it the better choice for any agent that requires continuity.

#### 3. Cost Efficiency Rules

*   **/clear is more cost-effective when**:
    *   An agent's tasks are **short-lived, atomic, and stateless**.
    *   The full state required for a task is provided externally (e.g., in a `task.yaml`).
    *   Preventing context pollution from a previous, unrelated task is critical.

*   **/compact is more cost-effective when**:
    *   An agent's task is **long-running and requires iterative reasoning**.
    *   Maintaining a "train of thought" or strategic overview is essential.
    *   The cost of reloading the full context is prohibitive or would lead to loss of crucial, unwritten information.

*   **Optimal Strategy per Agent**:
    *   **ashigaru (Worker)**: **`/clear`** after every task. Their work is transactional, defined by a single YAML file. This is the cheapest and cleanest approach.
    *   **karo (Manager)**: **Mixed Strategy**. The manager must track multiple agents and task statuses over time. `/compact` preserves this operational awareness, while a periodic `/clear` prevents context degradation.
    *   **shogun (Orchestrator)**: **`/compact`** almost exclusively. The shogun's role is strategic and long-term. Losing its high-level context via `/clear` would be detrimental. A `/clear` should only be a manual emergency measure.

### Section 5: Multi-Agent Optimization Strategies

Effective context management is crucial in a hierarchical agent system. The strategy must be tailored to the role of each agent.

1.  **For Workers (ashigaru)**:
    *   **Strategy**: Use `/clear` upon task completion.
    *   **Why**: Ashigaru are single-task agents. Their instructions and task data are delivered in a self-contained YAML file. They do not need to remember past work. Using `/clear` ensures they start every new task with a clean slate, preventing context from a previous task from "leaking" and causing errors. This is the most robust and cost-effective method for ephemeral workers.

2.  **For Manager (karo)**:
    *   **Strategy**: Employ the Context Threshold Management rules outlined in `CLAUDE.md`.
        *   **60-75% Usage (警戒)**: Finish the current work cycle, then use `/compact`. This preserves the operational context (e.g., which ashigaru is working on which task) while trimming less relevant data.
        *   **75-85% Usage (危険)**: Immediately use `/compact`. The risk of hitting the hard limit is high, so compaction is prioritized to maintain the session.
        *   **85%+ Usage (緊急)**: Immediately use `/clear`. At this point, context is likely too fragmented or bloated for a clean summary. A hard reset is the safest option to ensure stability, even at the cost of losing the immediate "train of thought." The manager can then recover its state by reading the various `report.yaml` files.

3.  **For Orchestrator (shogun)**:
    *   **Strategy**: A decision tree that heavily favors `/compact`.
    *   **Decision Tree**:
        1.  Is context usage > 75%?
            *   **Yes**: Proceed to step 2.
            *   **No**: Continue working.
        2.  Is the current strategic initiative complete or at a major milestone?
            *   **Yes**: This is a natural point for a "clean-up". Consider a `/clear` *if and only if* the strategic state is fully persisted in `dashboard.md` or other planning documents. Otherwise, use `/compact`.
            *   **No**: Use `/compact`. The strategic train of thought is active and must be preserved. A `/clear` would be equivalent to wiping the whiteboard in the middle of a strategy session.

4.  **Memory MCP and Data Patterns**:
    *   **Data Segregation**:
        *   **Memory MCP**: Stores **immutable, foundational knowledge**. This includes core rules, system architecture principles, and key instructions that change rarely. (e.g., "Files must be read before editing").
        *   **YAML Files (`queue/`, `status/`)**: Stores **transactional, stateful data**. This is the "single source of truth" for tasks, reports, and agent statuses. It's structured, machine-readable, and represents the current state of the system's work.
        *   **Claude Context**: The agent's **short-term memory or "RAM"**. It holds the train of thought, recent file contents, and deductions made during a session. It is volatile and managed by `/compact` and `/clear`.
    *   **Optimal Read Order on Recovery (`/clear`)**:
        1.  `CLAUDE.md` / `instructions/*.md`: Re-establish identity and core rules.
        2.  `Memory MCP`: Load the long-term, unchanging principles.
        3.  `dashboard.md`: Get a high-level overview of system status (for Shogun/Karo).
        4.  `queue/tasks/{self}.yaml`: Load the specific, immediate task.
    *   **Avoiding Redundancy**: The strict separation of concerns is key. Don't store task descriptions (YAML data) in the Memory MCP. Don't put core rules (MCP data) into a task YAML. The context is for *reasoning about* the data, not for storing it long-term.

5.  **Hot-standby Pattern**:
    *   **Concept**: Yes, context can be handed off between Claude Code instances, enabling a resilient hot-standby system for critical agents like the Karo.
    *   **State Serialization**:
        1.  The active agent (Karo-1) periodically serializes its essential state into a dedicated YAML file (e.g., `status/karo_state.yaml`). This state would include a list of active tasks, assigned ashigaru, and pending reports.
        2.  For a planned handoff, Karo-1 can execute a final `/compact` and write the resulting summary to a markdown file (e.g., `status/karo_handoff.md`).
    *   **Recovery Protocol**:
        1.  A monitoring system (or the Shogun) detects that Karo-1 is unresponsive or has gone into an `/clear` cycle due to reaching the 85% threshold.
        2.  The Shogun activates the standby agent (Karo-2) via a `tmux send-keys` command.
        3.  Karo-2's initial instruction is to execute the recovery protocol:
            a. Read its instructions (`instructions/karo.md`).
            b. Read the serialized state file (`status/karo_state.yaml`) to understand the operational picture.
            c. (Optional) Read the handoff summary (`status/karo_handoff.md`) to get the last known "train of thought".
            d. Announce its active status by updating `dashboard.md`.
            e. Begin processing the task queue.

I will now proceed with Section 6, which requires web searches.
### Section 6: Community Knowledge

This section summarizes findings from public sources regarding Claude Code's context management features. The information is sourced from GitHub issue trackers, technical blogs, and documentation.

*(Disclaimer: The following information is based on publicly available, user-reported data and may not reflect the most current, unreleased versions of the software. Direct links are provided where possible, sourced from search results.)*

---

#### English Version

**1. GitHub Issues (anthropics/claude-code)**

The official GitHub repository contains numerous user reports detailing significant bugs and limitations with the `/clear` and `/compact` commands.

*   **Ineffectiveness of Context Clearing**: A common and critical complaint is that `/clear` and `/compact` often fail to work as expected. Users report that after using the commands, the context meter remains abnormally high (e.g., "102%") or drops momentarily before returning to a high level with minimal new input.
    *   *Quote*: "Multiple GitHub issues report problems with Claude Code's context management. Users experience situations where the context consistently shows high percentages (e.g., 102%) even after using `/clear` or `/compact`..."
    *   *Source*: [GitHub Issue Summary 1](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQF4qFhq1GDPEfK9YvT9EqLkanJOtLZo8_PffygoCz66iV2sU4jUZ7jnEo2DisxxxQTcYAu5KfOdYaCg2mTO1fYfKPDROqzz7PGuF_iK1PspNGzA8FC8jFZuqoWWwmMJ3gbEoEK8JvD0ICIVGfTyN8WP), [GitHub Issue Summary 2](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQFd6O0ShElqgb5O_h_35yGc5xQKJfFOXpbxSX8jTNR73S3LkdeSSLWlbRzXkfvworzZh41KttuZWaOahvxpHsL7OWzuWCOjUDT4NPNiduxb92Z6984lpxE6zn-31dHa13c4_HuDBrGAQNXpGfm8M6s7)

*   **Auto-Compaction Bugs**: Several issues describe a buggy auto-compaction feature that triggers at very low context thresholds (e.g., 8-12% instead of the expected 85%+). This bug can render the tool unusable by constantly interrupting the user's workflow.
    *   *Quote*: "There are reports of auto-compact triggering at unusually low context percentages (e.g., 8-12% instead of 90-95%+), making the tool unusable due to frequent interruptions."
    *   *Source*: [GitHub Auto-Compact Bug Report](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQEMe1Gcj3nwZPzjzbbKNYlixOGqt2ZTp3D_fB4PM4g4ofjGd0pQcGg7V7SZW9p1CBAaNWwDdC8RvXd1fNV9x9QKEyY_5gVoPNqCfFiPQpFqFDZ_cePFQU7xfL_Fpjc7x01LYTfRUYnbaUHQV6JNjnrJ)

*   **Feature Request for Programmatic Reset**: Acknowledging these issues, there is a feature request for a more reliable, programmatically invokable `/reset` or `/compact` command. This would allow developers to clear conversational context while preserving the project state, which is crucial for iterative development.
    *   *Source*: [GitHub Feature Request](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQFEClx7NXx80OxScu1vNz4jQIBhDJlpvZUz5tr1cMn4p0B96UJ3E-eNT2ImGrGO_pBqwl06fOICOLciWC-N2J04a5Yme2S4P4LALmdIhPW3usp4OMYevzsNJz5sazFa0GCsr0bumkvOr4xJx6ogJ_aARA==)

**2. Blog Posts and Articles**

Technical articles and documentation echo the strategies developed internally for the multi-agent system, emphasizing proactive context management.

*   **Best Practices**: A recurring theme is that effective use of Claude Code requires a disciplined approach to context.
    *   **Aggressive `/clear` Usage**: "Troubleshooting guides suggest using `/clear` frequently to reset context windows..." This is seen as the most reliable, albeit blunt, method for preventing context-related performance issues.
    *   **Context Engineering**: Advanced users employ a "Context Engineering framework" which includes designing token-efficient tools, using `CLAUDE.md` files to provide stable context, and maintaining "living plans" to offload long-term strategy from the immediate context window.
    *   *Source*: [Milvus.io Troubleshooting Guide](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQEKnNlSzpjfr4XGxwDFqVpMPF4dfwn45ZYlJHzlEV-iRhyvoXQ8mBgxkLNBOJ_YdVjCsVWTbi2Uw4ehb5Qw7hzJMdMTFnb9y9IX_mcDCWNBSqA88ZdM9q2Sf5yvh-ogBdKdOEmaXwVkc23m1BTtPTOPDrXPIfR4oevXc0XLXK3OjUS5ervDCMkEYy80jNmP8yb3TpqW), [Context Engineering Framework Overview](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQGjN3_ReDV8Itq9MqKQqbeAk9ogeII5UbvhYE-TsAbJXsRy1C7O5a0ihZ7YC-Ojw-mpl3wuzcS9Ty73yHcBBCPUeDTJGnoPNiuslKfk0ZGNoXYSw0B2SFyeUWDngrkluwDtVZkmDkLH8yqW1qMzLHvOtCAF)

**3. Known Bugs, Limitations, and Workarounds**

*   **Bugs**:
    *   Auto-compaction triggers incorrectly at low usage levels.
    *   `/compact` can fail with a "Conversation too long" error, even when it's being used to solve that very problem.
*   **Limitations**:
    *   The primary limitation is the unreliability of `/compact`. Users cannot depend on it to cleanly summarize and reduce context as advertised.
    *   "Context degradation" is cited as the main failure mode in long-running sessions.
*   **Workarounds**:
    *   The most prevalent community-endorsed workaround is the **frequent and aggressive use of the `/clear` command**.
    *   Supplementing context with well-maintained external documents (`CLAUDE.md`, planning files) is crucial for recovering state after a `/clear`. This externalization of memory is a key pattern for successful, long-term use.

**4. Upcoming Features**

Public information regarding specific upcoming features for context management is scarce. Development appears to be focused on improving the core reliability of existing features rather than introducing entirely new ones.

---

#### 日本語訳 (Japanese Translation)

**1. GitHubイシュー (anthropics/claude-code)**

公式のGitHubリポジトリには、`/clear`および`/compact`コマンドに関する重大なバグや制限事項を詳述した多数のユーザーレポートが含まれています。

*   **コンテキスト消去の非効率性**: 共通かつ重大な不満点として、`/clear`と`/compact`が期待通りに機能しないことが頻繁に報告されています。ユーザーは、コマンド使用後もコンテキストメーターが異常に高い値（例：「102%」）のままであるか、一時的に低下しても最小限の新しい入力ですぐに高いレベルに戻ってしまうと報告しています。
    *   *引用*: 「複数のGitHubイシューがClaude Codeのコンテキスト管理に関する問題を報告しています。ユーザーは`/clear`や`/compact`を使用した後でも、コンテキストが一貫して高いパーセンテージ（例：102%）を示す状況を経験しています…」
    *   *出典*: [GitHub Issue Summary 1](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQF4qFhq1GDPEfK9YvT9EqLkanJOtLZo8_PffygoCz66iV2sU4jUZ7jnEo2DisxxxQTcYAu5KfOdYaCg2mTO1fYfKPDROqzz7PGuF_iK1PspNGzA8FC8jFZuqoWWwmMJ3gbEoEK8JvD0ICIVGfTyN8WP), [GitHub Issue Summary 2](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQFd6O0ShElqgb5O_h_35yGc5xQKJfFOXpbxSX8jTNR73S3LkdeSSLWlbRzXkfvworzZh41KttuZWaOahvxpHsL7OWzuWCOjUDT4NPNiduxb92Z6984lpxE6zn-31dHa13c4_HuDBrGAQNXpGfm8M6s7)

*   **自動圧縮のバグ**: いくつかのイシューでは、非常に低いコンテキスト閾値（期待される85%+ではなく、8-12%など）でトリガーされる自動圧縮機能のバグが報告されています。このバグは、ユーザーのワークフローを絶えず中断させるため、ツールが使用不能になる可能性があります。
    *   *引用*: 「自動圧縮が異常に低いコンテキストパーセンテージ（例：90-95%+ではなく8-12%）でトリガーされ、頻繁な中断のためにツールが使用不能になるという報告があります。」
    *   *出典*: [GitHub Auto-Compact Bug Report](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQEMe1Gcj3nwZPzjzbbKNYlixOGqt2ZTp3D_fB4PM4g4ofjGd0pQcGg7V7SZW9p1CBAaNWwDdC8RvXd1fNV9x9QKEyY_5gVoPNqCfFiPQpFqFDZ_cePFQU7xfL_Fpjc7x01LYTfRUYnbaUHQV6JNjnrJ)

*   **プログラム的なリセットの機能リクエスト**: これらの問題を認識し、より信頼性が高く、プログラム的に呼び出し可能な`/reset`または`/compact`コマンドの機能リクエストが存在します。これにより、開発者はプロジェクトの状態を保持しつつ会話のコンテキストを消去でき、反復的な開発において極めて重要です。
    *   *出典*: [GitHub Feature Request](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQFEClx7NXx80OxScu1vNz4jQIBhDJlpvZUz5tr1cMn4p0B96UJ3E-eNT2ImGrGO_pBqwl06fOICOLciWC-N2J04a5Yme2S4P4LALmdIhPW3usp4OMYevzsNJz5sazFa0GCsr0bumkvOr4xJx6ogJ_aARA==)

**2. ブログ投稿と技術記事**

技術記事やドキュメントは、マルチエージェントシステムのために内部で開発された戦略と同様に、積極的なコンテキスト管理を強調しています。

*   **ベストプラクティス**: 繰り返し語られるテーマは、Claude Codeを効果的に使用するには、コンテキストに対する規律あるアプローチが必要であるということです。
    *   **積極的な`/clear`の使用**: 「トラブルシューティングガイドは、コンテキストウィンドウをリセットするために`/clear`を頻繁に使用することを提案しています…」。これは、コンテキスト関連のパフォーマンス問題を防ぐための最も信頼できる、しかし直接的な方法と見なされています。
    *   **コンテキストエンジニアリング**: 上級ユーザーは「コンテキストエンジニアリングフレームワーク」を採用しています。これには、トークン効率の良いツールの設計、安定したコンテキストを提供するための`CLAUDE.md`ファイルの使用、長期的な戦略を即時のコンテキストウィンドウから切り離すための「生きた計画書」の維持などが含まれます。
    *   *出典*: [Milvus.io Troubleshooting Guide](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQEKnNlSzpjfr4XGxwDFqVpMPF4dfwn45ZYlJHzlEV-iRhyvoXQ8mBgxkLNBOJ_YdVjCsVWTbi2Uw4ehb5Qw7hzJMdMTFnb9y9IX_mcDCWNBSqA88ZdM9q2Sf5yvh-ogBdKdOEmaXwVkc23m1BTtPTOPDrXPIfR4oevXc0XLXK3OjUS5ervDCMkEYy80jNmP8yb3TpqW), [Context Engineering Framework Overview](https://vertexaisearch.cloud.google.com/grounding-api-redirect/AUZIYQGjN3_ReDV8Itq9MqKQqbeAk9ogeII5UbvhYE-TsAbJXsRy1C7O5a0ihZ7YC-Ojw-mpl3wuzcS9Ty73yHcBBCPUeDTJGnoPNiuslKfk0ZGNoXYSw0B2SFyeUWDngrkluwDtVZkmDkLH8yqW1qMzLHvOtCAF)

**3. 既知のバグ、制限、および回避策**

*   **バグ**:
    *   自動圧縮が低い使用率レベルで誤ってトリガーされる。
    *   `/compact`が、まさにその問題を解決するために使用されているにもかかわらず、「Conversation too long」エラーで失敗することがある。
*   **制限**:
    *   主な制限は、`/compact`の信頼性の低さです。ユーザーは、宣伝されているようにコンテキストをクリーンに要約し、削減することを期待できません。
    *   「コンテキストの劣化」が、長時間のセッションにおける主要な失敗モードとして挙げられています。
*   **回避策**:
    *   コミュニティで最も広く支持されている回避策は、**`/clear`コマンドを頻繁かつ積極的に使用する**ことです。
    *   `/clear`の後に状態を回復するためには、手入れの行き届いた外部ドキュメント（`CLAUDE.md`、計画ファイル）でコンテキストを補うことが不可欠です。このメモリの外部化は、長期間にわたる安定した使用のための重要なパターンです。

**4. 今後の機能**

コンテキスト管理に関する特定の今後の機能についての公開情報はほとんどありません。開発は、全く新しい機能の導入よりも、既存の機能の核心的な信頼性の向上に焦点を当てているようです。
