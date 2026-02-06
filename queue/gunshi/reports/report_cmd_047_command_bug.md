This is a solid, very fixable issue—thanks for the clear brief. Here’s the full trace and a precise fix plan tied to exact files and line numbers.

**Execution Flow (POST /api/command)**
1. `main.py` defines the endpoint at `/api/command`.  
   File: `/home/quieter/projects/shogun-web/main.py`  
   Lines: 42–60  
   It instantiates `TmuxBridge()` and calls `bridge.send_to_shogun(instruction)`.

2. `TmuxBridge.send_to_shogun` is implemented in:  
   File: `/home/quieter/projects/shogun-web/ws/tmux_bridge.py`  
   Lines: 119–144  
   It uses `libtmux` to target the `shogun` session’s pane `0`.

3. There is **no** `tmux send-keys` subprocess call anywhere in the codebase.

**Why It Writes YAML Instead of `tmux send-keys`**
- The **only** YAML write path in this codebase is `TmuxBridge.add_command` in:  
  `/home/quieter/projects/shogun-web/ws/tmux_bridge.py` lines 172–228  
  This appends `cmd_XXX` entries to `queue/shogun_to_karo.yaml`.
- However, **/api/command does not call `add_command`** at all.  
- That means one of two things is happening:
  1. You are running a different build/version where `/api/command` was wired to `add_command`, or  
  2. Another process in the stack is writing that YAML entry, and you’re seeing it as a side effect after submitting.
- In the current codebase, `/api/command` attempts to use `libtmux` to the **`shogun` session**, not `multiagent:main.0`, and **never calls `tmux send-keys`**.

**Required Fix (exact file, lines, code changes)**
Goal: Make POST `/api/command` execute **two subprocess calls**:
1. `tmux send-keys -t multiagent:main.0 '<user_input>'`
2. `tmux send-keys -t multiagent:main.0 Enter`

Do the following changes:

1. **Add `subprocess` import**  
   File: `/home/quieter/projects/shogun-web/ws/tmux_bridge.py`  
   Line: 8  
   Change:
   ```python
   import libtmux
   ```
   To:
   ```python
   import libtmux
   import subprocess
   ```

2. **Replace the body of `send_to_shogun`**  
   File: `/home/quieter/projects/shogun-web/ws/tmux_bridge.py`  
   Lines: 119–144  
   Replace the current libtmux-based implementation with this exact code:

   ```python
   def send_to_shogun(self, message: str) -> bool:
       """
       Send a message to the shogun pane (multiagent:main.0).
       """
       target = "multiagent:main.0"
       try:
           subprocess.run(
               ["tmux", "send-keys", "-t", target, message],
               check=True,
           )
           subprocess.run(
               ["tmux", "send-keys", "-t", target, "Enter"],
               check=True,
           )
           return True
       except (subprocess.CalledProcessError, FileNotFoundError):
           return False
   ```

This ensures `/api/command` now uses the exact tmux command sequence you specified, with **two discrete subprocess calls**.

**Test Plan**
1. Unit tests (safe to run):
   - `pytest /home/quieter/projects/shogun-web/tests/test_api.py`
   - Confirm `/api/command` still returns `{"status":"sent"}` when `send_to_shogun` returns `True`.

2. Manual functional test (requires tmux session):
   1. Ensure tmux session + window exists: `multiagent:main.0`.
   2. Run the FastAPI app.
   3. POST a command:
      ```bash
      curl -X POST -F 'instruction=echo hello' http://localhost:30000/api/command
      ```
   4. Verify in tmux pane `multiagent:main.0`:
      - The exact text appears.
      - It is followed by an Enter press and executes.

3. Regression check:
   - Confirm that `queue/shogun_to_karo.yaml` no longer receives a new `cmd_XXX` entry after POSTing to `/api/command`.

If you want, I can also sketch a quick unit test that mocks `subprocess.run` to validate the exact command invocations for `send_to_shogun`.
