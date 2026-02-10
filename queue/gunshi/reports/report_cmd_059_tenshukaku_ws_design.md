Absolutely—this is a fun, meaty systems design brief, and I’m excited to lay it out cleanly and concretely for us.

Below is a detailed design document that satisfies P0–P3, maps to your current layout, and calls out file touchpoints, interfaces, and rollout order.

**Design Doc: WebSocket Broadcast Architecture for FastAPI + tmux Monitoring**

**Goals**
- Replace per-connection polling with shared broadcaster loops.
- Serialize tmux access to avoid concurrency hazards.
- Reduce payload size via per-pane diffing.
- Adapt polling interval based on change frequency.
- Improve error handling and cleanup.
- Cache `dashboard.md` using mtime.

**Non-Goals**
- No UI redesign, only minimal wiring for diff merge.
- No tmux API refactor beyond adding thread pool/lock wrappers.

---

**1) File Structure**

**New files**
- `ws/broadcasters.py`
  - `MonitorBroadcaster`
  - `ShogunBroadcaster`
  - `AdaptivePoller`
- `ws/dashboard_cache.py`
  - `DashboardCache`
- `ws/runtime.py`
  - `TmuxRuntime` (thread pool + lock + to_thread wrappers)
- `ws/state.py`
  - `PaneState` (hash tracking, diff logic)

**Modified files**
- `main.py`
  - Add lifespan startup/shutdown hooks.
  - Instantiate broadcasters and `TmuxRuntime`.
  - Wire broadcasters into handlers.
- `ws/handlers.py`
  - Replace looped polling with subscribe/unsubscribe.
  - Proper exception handling and cleanup.
- `ws/tmux_bridge.py`
  - Convert blocking calls into sync-only helpers; no asyncio.
  - Remove direct thread pool usage here.
  - Add optional `DashboardCache` usage in `read_dashboard`.
- `config/settings.yaml`
  - Add adaptive polling settings and thread pool size.
- `templates/index.html`
  - Merge strategy for diff updates.

---

**2) Interfaces (Type Hints Included)**

**`ws/runtime.py`**
```python
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import asyncio
from typing import Callable, TypeVar, Any

T = TypeVar("T")

@dataclass
class TmuxRuntime:
    executor: ThreadPoolExecutor
    lock: asyncio.Lock

    async def run_locked(self, fn: Callable[..., T], *args: Any, **kwargs: Any) -> T:
        async with self.lock:
            return await asyncio.to_thread(fn, *args, **kwargs)

    async def run_unlocked(self, fn: Callable[..., T], *args: Any, **kwargs: Any) -> T:
        return await asyncio.to_thread(fn, *args, **kwargs)
```

**Lock granularity design**
- Lock required for: any tmux command that reads or writes tmux server state.
- Unlock allowed for: pure file IO (`dashboard.md`, yaml command history).
- This keeps tmux operations serialized while allowing cheap reads concurrently.

**`ws/state.py`**
```python
from __future__ import annotations
from dataclasses import dataclass
from typing import Dict
import hashlib

@dataclass
class PaneState:
    hashes: Dict[str, str]

    def diff(self, panes: Dict[str, str]) -> Dict[str, str]:
        updates: Dict[str, str] = {}
        for pane_id, output in panes.items():
            h = hashlib.sha1(output.encode("utf-8")).hexdigest()
            if self.hashes.get(pane_id) != h:
                self.hashes[pane_id] = h
                updates[pane_id] = output
        return updates
```

**`ws/broadcasters.py`**
```python
from __future__ import annotations
import asyncio
import time
from dataclasses import dataclass, field
from typing import Set, Dict, Any, Optional
from fastapi import WebSocket
from .tmux_bridge import TmuxBridge
from .runtime import TmuxRuntime
from .state import PaneState
from .dashboard_cache import DashboardCache

@dataclass
class AdaptivePoller:
    base_interval: float
    max_interval: float
    no_change_threshold: int
    current_interval: float = field(init=False)
    no_change_count: int = field(default=0)

    def __post_init__(self) -> None:
        self.current_interval = self.base_interval

    def on_change(self) -> None:
        self.no_change_count = 0
        self.current_interval = self.base_interval

    def on_no_change(self) -> None:
        self.no_change_count += 1
        if self.no_change_count >= self.no_change_threshold:
            self.current_interval = min(self.max_interval, self.current_interval * 2)

@dataclass
class MonitorBroadcaster:
    tmux: TmuxBridge
    runtime: TmuxRuntime
    poller: AdaptivePoller
    subscribers: Set[WebSocket] = field(default_factory=set)
    pane_state: PaneState = field(default_factory=lambda: PaneState({}))
    task: Optional[asyncio.Task[None]] = None
    running: bool = False

    async def start(self) -> None: ...
    async def stop(self) -> None: ...
    async def subscribe(self, ws: WebSocket) -> None: ...
    async def unsubscribe(self, ws: WebSocket) -> None: ...
    async def _loop(self) -> None: ...

@dataclass
class ShogunBroadcaster:
    tmux: TmuxBridge
    runtime: TmuxRuntime
    poller: AdaptivePoller
    subscribers: Set[WebSocket] = field(default_factory=set)
    last_hash: Optional[str] = None
    task: Optional[asyncio.Task[None]] = None
    running: bool = False

    async def start(self) -> None: ...
    async def stop(self) -> None: ...
    async def subscribe(self, ws: WebSocket) -> None: ...
    async def unsubscribe(self, ws: WebSocket) -> None: ...
    async def _loop(self) -> None: ...
```

**Loop semantics**
- `MonitorBroadcaster._loop`
  - `panes = await runtime.run_locked(tmux.capture_all_panes)`
  - `updates = pane_state.diff(panes)`
  - If `updates` non-empty: `poller.on_change()` else `poller.on_no_change()`
  - `payload = {"ts": now, "updates": updates}`
  - Broadcast to all subscribers; drop failed websockets.
  - Sleep `poller.current_interval`.
- `ShogunBroadcaster._loop`
  - `output = await runtime.run_locked(tmux.capture_shogun_pane)`
  - Hash + diff, send only on change.
  - `{"ts": now, "output": output}`

**`ws/dashboard_cache.py`**
```python
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
import os

@dataclass
class DashboardCache:
    path: Path
    last_mtime: float = 0.0
    cached_content: str = ""

    def read(self) -> str:
        stat = os.stat(self.path)
        if stat.st_mtime != self.last_mtime:
            self.cached_content = self.path.read_text(encoding="utf-8")
            self.last_mtime = stat.st_mtime
        return self.cached_content
```

**`ws/handlers.py` adjustments**
```python
from fastapi import WebSocket, WebSocketDisconnect
import logging

async def ws_handler(ws: WebSocket, broadcaster: ShogunBroadcaster) -> None:
    await ws.accept()
    await broadcaster.subscribe(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception:
        logging.error("WebSocket error", exc_info=True)
    finally:
        await broadcaster.unsubscribe(ws)
        await ws.close()

async def monitor_ws_handler(ws: WebSocket, broadcaster: MonitorBroadcaster) -> None:
    await ws.accept()
    await broadcaster.subscribe(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception:
        logging.error("WebSocket error", exc_info=True)
    finally:
        await broadcaster.unsubscribe(ws)
        await ws.close()
```

**`ws/tmux_bridge.py`**
- Keep synchronous API; no `async` here.
- Remove any direct `asyncio` usage.
- `read_dashboard()` uses `DashboardCache` (injected or optional).

---

**3) Frontend Change Plan (`templates/index.html`)**

**Current behavior**
- Client expects full pane payload each tick.

**New behavior**
- Maintain an in-memory map keyed by `pane_id`.
- Merge incremental updates.

**Pseudo-logic**
```js
const panes = {}; // pane_id -> output

ws.onmessage = (evt) => {
  const msg = JSON.parse(evt.data);
  if (msg.updates) {
    Object.entries(msg.updates).forEach(([paneId, output]) => {
      panes[paneId] = output;
    });
    renderPanes(panes);
  } else if (msg.output) {
    renderShogun(msg.output);
  }
};
```

**Notes**
- `renderPanes` should rebuild the view from `panes` to preserve order.
- If you have a known order from tmux (pane index), keep a separate list, else stable sort by key.

---

**4) Final `settings.yaml` Structure**

```yaml
server:
  host: "0.0.0.0"
  port: 8000

bakuhu:
  dashboard_path: "dashboard.md"
  command_history_path: "shogun_to_karo.yaml"

tmux:
  server_name: "default"
  shogun_session: "shogun"
  monitor_session: "multiagent"

runtime:
  thread_pool_workers: 2

monitor:
  base_interval_ms: 5000
  max_interval_ms: 10000
  no_change_threshold: 2

shogun:
  base_interval_ms: 1000
  max_interval_ms: 3000
  no_change_threshold: 2
```

**Conversion**
- `AdaptivePoller` uses seconds, so divide by `1000.0` at load.

---

**5) Implementation Order (Dependencies Aware)**

1. Add `TmuxRuntime` and wire into app lifespan in `main.py`.
2. Introduce `AdaptivePoller` and `PaneState`.
3. Build `MonitorBroadcaster` and `ShogunBroadcaster` in `ws/broadcasters.py`.
4. Update `ws/handlers.py` to subscribe/unsubscribe, remove polling loops.
5. Update `ws/tmux_bridge.py` to stay sync-only and accept `DashboardCache`.
6. Add `DashboardCache` and wire into tmux bridge.
7. Update `settings.yaml` and `load_settings()` to include new keys.
8. Modify `templates/index.html` for diff-merge.

---

**6) Test Strategy**

**Unit tests**
- `PaneState.diff`
  - No change returns `{}`.
  - Single pane change returns only that pane.
  - Add/remove panes behaves correctly.
- `AdaptivePoller`
  - `on_change()` resets interval.
  - `on_no_change()` increases interval after threshold.

**Integration tests**
- Broadcaster loop with mocked `TmuxBridge`.
  - Broadcast only on diff.
  - Poller interval changes on no-change streaks.

**Manual smoke**
- Launch app; connect two clients.
- Verify both receive identical updates.
- Verify send to shogun still works.
- Edit `dashboard.md` and ensure new content appears.

---

**Concurrency and Locking Summary**

- `TmuxRuntime.lock` ensures serialized tmux access to avoid overlapping `libtmux` or `tmux` CLI calls.
- All tmux reads/writes are wrapped in `run_locked`.
- Pure file reads (`dashboard.md`, yaml command history) can be `run_unlocked`.

---

If you want, I can turn this into a concrete patch next. Suggested next steps:
1. “Implement P0 only”
2. “Implement all P0–P1”
3. “Generate patches for full P0–P3”
