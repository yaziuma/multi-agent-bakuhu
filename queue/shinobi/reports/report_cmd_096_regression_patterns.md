Here is the research on regression patterns when converting from generator-based execution to an explicit stack.

### 1. Common Regression Patterns in Generator → Explicit Stack Conversion

Converting from an implicit `yield from` control flow to an explicit stack-based loop is error-prone because `yield from` (as defined in PEP 380) handles significant protocol complexity automatically. The most common regressions arise from failing to manually reimplement this protocol correctly.

*   **Generator Lazy Evaluation Semantics**:
    *   **Pitfall**: A `yield from` chain is fully lazy. A common bug is to eagerly evaluate parts of the logic that the generator would have deferred. For instance, pre-calculating values that should only be computed when a frame is actually stepped. The explicit stack loop must ensure that computation only happens within `frame.step()`, preserving the lazy evaluation semantics.

*   **Parent-Child Frame Communication Gaps**:
    *   **`StopIteration` Propagation**: This is the most frequent source of bugs. `yield from` automatically catches `StopIteration` raised by a sub-generator and uses its `value` attribute as the return value of the expression.
        *   **Regression**: Your `while` loop must explicitly `try...except StopIteration` around `frame.step()`. When caught, you must pop the completed frame, inspect the exception's `value`, and pass that result to the new parent frame (the one now at `stack[-1]`). If this is not done, the return value is lost, or the exception propagates and crashes the loop.
    *   **`.send()` and `.throw()` Delegation**: `yield from` transparently passes values from `.send()` and exceptions from `.throw()` to the current sub-generator.
        *   **Regression**: Your explicit loop will break this communication. A call to `interpreter.send(value)` must be manually routed to the frame at the top of the stack (`stack[-1].step(value)`). Likewise, exceptions must be manually thrown into the top frame (`stack[-1].throw(exc)`). Failure to implement this plumbing breaks any interaction or external control of the execution flow.

*   **Backtracking Semantics**:
    *   **Pitfall**: In Prolog, backtracking is fundamental. A generator-based system naturally models this: a choice point is a generator that can be iterated again to produce more solutions.
    *   **Regression**: With an explicit stack, a `frame` object must manage its own choice point state internally. When `frame.step()` yields a solution (`YieldEnv`), it must *not* exhaust itself. It must be ready to be called again to produce the next solution. If `step()` discards its iterator or choice point information after yielding once, backtracking is broken. The frame must retain its internal state (e.g., which clause to try next) across `YieldEnv` results.

*   **State Sharing vs. Copying Issues**:
    *   **Pitfall**: Prolog environments (variable bindings) are mutable but must be correctly trailed and unwound on backtracking.
    *   **Regression**: When a `PushFrame` occurs for a new goal, it's critical to determine if the environment should be a copy or a reference. If a child goal modifies the environment and then fails, those modifications must be undone. A generator-based approach might implicitly handle this via local scope. In an explicit model, you must either:
        1.  Pass deep copies of the environment (inefficient).
        2.  Implement a "trail" stack. Before binding a variable, you record its address and current value on the trail. On backtracking (e.g., when a frame is popped without success), you unwind the trail to restore the environment to its previous state.

### 2. Meta-predicates (findall, bagof, setof) Compatibility

Your meta-predicates break because they expect to iterate over a simple generator of `BindingEnvironment` solutions. The new `_execute_body_direct` loop, however, returns control-flow objects (`PushFrame`, `YieldEnv`).

*   **Typical Compatibility Issues**: The `findall` implementation now needs its own internal stack-based interpreter to handle the `PushFrame`/`YieldEnv` results from the goal it is evaluating. It can no longer be a simple `for env in _execute_body_direct(...)`.

*   **How WAM-based Implementations Handle `findall`**:
    1.  **Save State**: The WAM creates a choice point to save the machine's state before starting `findall`.
    2.  **Execute Goal and Collect**: It begins executing the goal. Each time a solution is successfully found, it copies the instantiated `Template` term to a temporary list on the **heap**.
    3.  **Force Failure (Backtracking)**: After copying the solution, it **artificially forces a failure**. This triggers the WAM's standard backtracking mechanism, which unwinds the state to the last choice point *within the goal's execution* and attempts to find the next solution.
    4.  **Repeat until Exhaustion**: This "succeed, copy, fail" loop continues until the goal is completely exhausted (i.e., it fails definitively).
    5.  **Restore and Unify**: The WAM then backtracks past the goal's execution entirely, restores the state saved in step 1, and unifies the collected list from the heap with the final argument of `findall/3`.

    For your system, `findall` needs to run its own `while stack:` loop on the goal. When it receives a `YieldEnv`, it copies the result, then tells the frame to backtrack and produce another. It continues until the frame signals it is exhausted.

### 3. Infinite Loop Patterns in Explicit Stack Execution

The `tak` benchmark hanging points to an infinite loop, likely caused by incorrect frame state management.

*   **Frame State Machine Getting Stuck**:
    *   **Cause**: A frame's `.step()` method must have a clear state progression. It might start in `INITIAL`, move to `EXECUTING`, and finish with `DONE`. A common bug is for `step()` to return `None` or a non-terminal value without advancing its internal state. The `while` loop then calls `.step()` again on the same frame in the same state, ad infinitum.
    *   **Example**: Your `GoalFrame.step()` might not be correctly consuming the results from a child frame. If a child frame (e.g., for an arithmetic goal) returns a value, the `GoalFrame` must use that value to advance its own logic. If it ignores the result and calls the same child again, it will loop.

*   **GoalFrame.step() Re-initializing Instead of Advancing**:
    *   **Cause**: This is a classic backtracking bug. The first time `.step()` is called, it initializes its search (e.g., starts iterating through clauses). When it yields a solution and is called *again* (to find the next solution), it must **resume** its search, not restart it. If it re-initializes, it will just yield the first solution again, leading to an infinite loop if the parent keeps asking for more solutions.

*   **Choice Points Not Being Properly Exhausted**:
    *   **Cause**: A frame representing a choice point must correctly signal when it has no more alternatives. If its logic for "are there more branches?" is flawed, it might keep trying the last branch (or an invalid branch) forever instead of raising `StopIteration` to signal its completion to the parent.

*   **`StopIteration` Not Propagating Correctly**:
    *   **Cause**: As mentioned in point 1, if the main `while` loop does not correctly catch `StopIteration`, pop the finished frame, and resume the new top frame, the system can get stuck. For instance, if you don't pop the finished frame, the loop will spin on a dead frame forever. This is a likely culprit in the `tak` benchmark, where deep recursion creates many frames that must be correctly created and destroyed.

### 4. Prolog WAM and Choice Points

*   **How WAM Manages Choice Points**: The WAM uses a single **local stack** to store two kinds of frames: **environments** (for deterministic code) and **choice points** (for non-deterministic code).
    *   When a predicate with multiple matching clauses is called, a **choice point frame** is pushed onto the local stack.
    *   This frame stores all the machine registers and state pointers (heap pointer, trail pointer, argument registers, continuation pointer) needed to fully restore the machine's state at that moment. Crucially, it also stores a pointer to the **next alternative clause** to try upon failure.
*   **How Backtracking Works**: When a goal fails, the WAM's instruction is simple: "find the most recent choice point and restore state." It traverses the stack backwards to find the last choice point frame, restores all the saved registers, unwinds the trail to undo variable bindings, and then jumps to the address of the alternative clause stored in the choice point.
*   **Key Differences from `PushFrame`/`YieldEnv`**:
    *   **Unified vs. Separate Stacks**: The WAM unifies control flow (continuations), local variables, and choice points on its local stack. Your approach seems to separate the explicit call stack (`stack`) from the mechanism for choice points, which must be managed *inside* each `Frame` object.
    *   **State Restoration**: The WAM's choice points are heavyweight; they save the *entire* machine state. Your approach appears more lightweight, where each frame is responsible only for its own state. The risk is that this distributed state management is harder to get right.
    *   **Backtracking as a Primitive**: In the WAM, backtracking is a fundamental machine operation. In your model, it's a pattern you must implement by having a frame re-invoke itself or its iterators.

### 5. Best Practices for Testing Generator→Stack Conversions

*   **Differential Testing (Golden Standard)**: This is the most effective strategy.
    *   **Method**: For a given goal, run both the old generator-based implementation and the new stack-based one.
    *   **Assert**:
        1.  The sequence of yielded solutions (`BindingEnvironment`s) must be identical in content and order.
        2.  The final result (success, failure, or exception) must be the same.
    *   This catches almost all regressions in logic, backtracking, and state handling.

*   **Property-Based Testing**: Use a library like `Hypothesis` to generate complex and nested goals. The "property" to test is that the output of the generator implementation matches the output of the stack implementation for any validly generated goal. This is excellent for finding edge cases in recursion and control flow.

*   **Systematic Path Verification**:
    *   **Unit Test Every Frame Type**: Each `Frame` subclass (`GoalFrame`, `ArithmeticFrame`, etc.) should be unit-tested. Test its state transitions: does it correctly `PushFrame`, `YieldEnv`, and finally raise `StopIteration`?
    *   **Test Communication**: Write specific tests for parent-child frame interactions. Create a mock child frame that returns a specific value and assert that the parent frame consumes it correctly. Create a test where a child frame signals exhaustion and ensure the parent handles it properly.
    *   **Test Backtracking Explicitly**: Write tests that force a frame to yield multiple solutions. Ensure it yields them all correctly and then signals completion. For example, test a predicate `member(X, [1,2,3])` and verify that your machinery yields three distinct solutions and then stops.
