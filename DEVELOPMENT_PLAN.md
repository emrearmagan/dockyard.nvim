# Dockyard.nvim - Complete Rewrite Plan


## Project Goal

Rewrite the **dockyard.nvim** Neovim plugin from scratch to:
1. **Learn Lua** - The author has no prior Lua experience
2. **Create clean architecture** - The backup was AI-generated with poor code quality
3. **Maintain feature parity** - Same functionality, better implementation

Dockyard.nvim is a **Docker management plugin for Neovim** that provides an interactive dashboard to manage containers, images, and networks without leaving the editor.

---

## Target Features

### Core Features
| Feature | Description |
|---------|-------------|
| **Containers View** | List all containers with status, start/stop/restart/remove actions |
| **Images View** | Tree view of images showing which containers use them |
| **Networks View** | Tree view of networks and connected containers |
| **Inspect Popup** | Floating window with detailed `docker inspect` output |
| **Terminal Shell** | Open shell inside running containers |
| **LogLens** | Stream and filter container logs with custom parsers |
| **Auto-Refresh** | Periodic refresh of Docker state |

### Keybindings
| Key | Action |
|-----|--------|
| `j/k` | Navigate rows |
| `Tab/S-Tab` | Switch views |
| `s` | Toggle start/stop |
| `x` | Stop container |
| `r` | Restart container |
| `d` | Remove (with confirmation) |
| `K/Enter` | Inspect details |
| `L` | View logs |
| `S` | Open shell |
| `o` | Toggle expand/collapse (trees) |
| `P` | Prune dangling images |
| `R` | Refresh |
| `?` | Help |
| `q` | Close |

---

## Architecture Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| **Error Handling** | Result pattern `{ok=bool, data=..., error=...}` | Explicit, easy to check |
| **Async Operations** | Callbacks `fn(callback)` | Standard Lua/plenary pattern |
| **State Management** | Module-level state | Simple, each module owns its data |
| **UI Rendering** | Full re-render | Predictable, easy to debug |
| **LogLens Design** | Source -> Parse -> Format -> Highlight pipeline | Fast, extensible, user-customizable |

---

## File Structure

```
dockyard.nvim/
├── plugin/
│   └── dockyard.lua              # Entry point (auto-loads on Neovim start)
│
└── lua/dockyard/
    ├── init.lua                  # Main API: setup(), open(), close(), refresh()
    ├── config.lua                # Default configuration & user config merging
    ├── docker.lua                # Docker CLI wrapper (uses plenary.job)
    ├── health.lua                # :checkhealth dockyard
    │
    ├── state/                    # Data layer - stores fetched Docker data
    │   ├── init.lua              # Exports: containers, images, networks
    │   ├── containers.lua        # Container state: refresh(), get_all(), get_by_id()
    │   ├── images.lua            # Image state
    │   └── networks.lua          # Network state
    │
    └── ui/                       # Presentation layer
        ├── init.lua              # UI manager: open(), close(), is_open()
        ├── state.lua             # UI state: win_id, buf_id, current_view
        ├── renderer.lua          # Main render orchestrator
        ├── highlights.lua        # Highlight groups & color palette
        ├── keymaps.lua           # Buffer-local keyboard shortcuts
        │
        ├── components/           # Reusable UI building blocks
        │   ├── header.lua        # Plugin title bar
        │   ├── navbar.lua        # Tab navigation [Containers] [Images] [Networks]
        │   └── table.lua         # Generic table renderer with columns
        │
        ├── views/                # Tab content renderers
        │   ├── containers.lua    # Containers list view
        │   ├── images.lua        # Images tree view
        │   └── networks.lua      # Networks tree view
        │
        ├── popups/               # Floating window UIs
        │   ├── inspect.lua       # Detail inspection popup
        │   └── help.lua          # Keybindings help popup
        │
        ├── terminal.lua          # Shell access (docker exec)
        │
        └── loglens/              # Log viewing subsystem
            ├── init.lua          # Log viewer UI & streaming
            └── parsers.lua       # Log formatters (JSON, custom)
```

---

## Module Responsibilities

### Core Modules

#### `init.lua` (Main Entry)
```lua
-- Public API
M.setup(opts)     -- Merge user config, setup highlights, commands
M.open()          -- Open as centered float (~80% screen)
M.open_full()     -- Open as full-screen float (100% overlay)
M.close()         -- Close the UI
M.refresh()       -- Refresh current view data
```

#### `config.lua`
```lua
-- Default configuration
M.defaults = {
    refresh_interval = 5000,  -- Auto-refresh in ms (0 to disable)
    views = { "containers", "images", "networks" },
    loglens = {
        max_lines = 2000,
        containers = {}  -- Per-container log config
    }
}
M.options = {}  -- Merged config stored here
M.setup(opts)   -- Merge user opts with defaults
```

#### `docker.lua`
```lua
-- All functions take a callback: callback({ok=bool, data=..., error=...})
M.list_containers(callback)
M.list_images(callback)
M.list_networks(callback)
M.container_action(id, action, callback)  -- action: start|stop|restart|rm
M.image_action(id, action, callback)      -- action: rm
M.network_action(id, action, callback)    -- action: rm
M.image_prune(callback)
M.inspect(type, id, callback)             -- type: container|image|network
M.logs(id, opts, on_line, on_exit)        -- Streaming logs
```

### State Modules

#### `state/containers.lua`
```lua
-- Module-level state
local items = {}
local last_updated = nil
local error = nil

M.refresh(callback)    -- Fetch from Docker, update state, call callback
M.get_all()            -- Return all containers
M.get_by_id(id)        -- Find container by ID
M.is_running(id)       -- Check if container is running
```

### UI Modules

#### `ui/state.lua`
```lua
M.win_id       = nil           -- Current window ID
M.buf_id       = nil           -- Current buffer ID
M.prev_win     = nil           -- Window focused before opening Dockyard
M.current_view = "containers"  -- Active tab
M.line_to_item = {}            -- Maps buffer line -> data item for actions
M.float_mode   = "panel"       -- "panel" (centered float) | "full" (full-screen float)
```

#### `ui/renderer.lua`
```lua
M.render()             -- Full re-render of current view
-- Internally calls: header.render(), navbar.render(), views[current].render()
```

#### `ui/components/table.lua`
```lua
-- Reusable table renderer
M.render(buf_id, columns, rows, start_line)
-- columns = {{name="Name", width=20, align="left"}, ...}
-- rows = {{values={...}, highlight="DockyardRunning"}, ...}
-- Returns: line_to_item mapping
```

### LogLens Architecture (Core)

`LogLens` is designed as a composable pipeline so we support all log sources and user customization without creating one giant `loglens.lua` file.

```lua
-- 1) Source adapter emits raw lines/chunks
source:start(on_chunk, on_exit)

-- 2) Framer splits stream into entries (newline-safe, JSON-safe)
framer:push(chunk) -> { entry1, entry2, ... }

-- 3) Parser converts entry to structured object
parsed = parser:parse(entry)

-- 4) Formatter builds render-ready view text/columns
view = formatter:format(parsed)

-- 5) Highlighter returns highlight spans/groups for renderer
spans = highlighter:spans(view, parsed)
```

#### Source adapters
- Docker source: `docker logs -f --tail N <container>` (stdout/stderr stream)
- File source: `docker exec <container> tail -n N -F <path>`

#### Parser/formatter/highlighter goals
- Plain text logs: pattern/level highlighting, minimal transform
- JSON logs: parse per-entry, preserve raw payload, structured formatting
- User rules: keyword + regex rules, per-container/per-source overrides

#### Performance goals
- Ring buffer with `max_lines` cap (no unbounded growth)
- Batched UI flush via timer (avoid redraw per line)
- Incremental append mode for live streams where possible
- Keep raw + parsed representation to avoid reparsing on every filter toggle

---

## Development Phases

### Phase 0: Lua Fundamentals & First Plugin
- [x] Clear folder and create structure
- [x] **LEARN**: Variables, types (string, number, boolean, nil)
- [x] Create `plugin/dockyard.lua` with `vim.notify("Hello!")`
- [x] **LEARN**: Tables (arrays and dictionaries)
- [x] **LEARN**: Functions, local scope, return values
- [x] **LEARN**: Control flow (if/else, for loops with pairs/ipairs)
- [x] **LEARN**: Modules, require(), M = {} pattern

### Phase 1: Config & Setup Pattern
- [x] Create `config.lua` with defaults
- [x] **LEARN**: `vim.tbl_deep_extend()` for merging tables
- [x] Create `init.lua` with `setup(opts)`
- [x] Test by notifying config values

## Phase 2: Docker Module (CLI Wrapper)
- [x] **LEARN**: `plenary.job` for async commands
- [x] Create `docker.lua` with module pattern
- [x] Implement `list_containers(callback)` with result pattern
- [x] **LEARN**: `vim.json.decode()` and `pcall()` for error handling
- [x] Add `list_images()`, `list_networks()`
- [x] Add `container_action()`, `inspect()`

### Phase 3: State Management
- [x] Create `state/init.lua` with factory function pattern (`create_state(fetch_fn)`)
- [x] **LEARN**: Closures — factory returns module with shared local state
- [x] Factory provides `refresh()`, `get_all()`, `get_by_id()`, `last_error()`, `last_updated()`
- [x] `state/containers.lua`, `state/images.lua`, `state/networks.lua` superseded by factory
- **Note**: Factory approach chosen over separate files to avoid code duplication

### Phase 4: UI Foundation
- [x] **LEARN**: `vim.api.nvim_*` functions (see PHASE_4_UI_FOUNDATION.md)
- [x] Create `ui/state.lua`
- [x] Create `ui/init.lua` with `open()` and `open_full()`
- [x] **Layout decision**: Both modes use floating windows (no splits, no tabs)
  - `open()` — centered float, configurable size (default ~90% of screen)
  - `open_full()` — full-screen float (100% width/height, overlays everything)
  - Shared `open_with(mode, win_config_fn)` helper for both modes
- [x] **LEARN**: Buffer options (buftype, modifiable)
- [x] Implement `close()`, `is_open()`

### Phase 5: Colors & Highlighting
- [x] **LEARN**: `vim.api.nvim_set_hl()`
- [x] Create `ui/highlights.lua` with color palette
- [x] Define highlight groups
- [x] **LEARN**: Extmarks for applying highlights

### Phase 6: Renderer & Layout
- [x] Create `ui/renderer.lua`
- [x] **LEARN**: `vim.api.nvim_buf_set_lines()`
- [x] Create `ui/components/header.lua`
- [x] Create `ui/components/navbar.lua`
- [x] **LEARN**: `string.format()`, `string.rep()`

### Phase 7: Table Foundation (shared for all views)
- [x] Create `ui/components/table.lua`
- [x] **LEARN**: `vim.fn.strdisplaywidth()` for unicode-safe width
- [x] Implement width calculation, truncation, alignment
- [x] Return line map + highlight spans (no side effects)

### Phase 8: Containers View (first complete workflow)
- [x] Create `ui/views/containers.lua`
- [x] Columns: Icon, Name, Image, Status, Ports
- [x] Transform state data -> table rows + row metadata
- [x] Integrate status highlighting (`DockyardRunning`, etc.)
- [x] Added Created column for better parity with Docker listing

### Phase 9: Navigation & Core Keymaps
- [ ] Create `ui/keymaps.lua`
- [ ] **LEARN**: `vim.keymap.set()` buffer-local maps
- [ ] Implement `j/k`, `Tab/S-Tab`, `q`, `R`, `?`
- [ ] Implement `get_item_at_cursor()` using line map

### Phase 10: Container Actions
- [ ] Implement `s`, `x`, `r`, `d` in action module
- [ ] **LEARN**: `vim.ui.select()`, `vim.ui.input()` confirmations
- [ ] Action -> refresh pipeline with error notifications

### Phase 11: Inspect Popup
- [ ] Create `ui/popups/inspect.lua`
- [ ] Implement `K/Enter` for selected item
- [ ] Pretty JSON view with scrollable float

### Phase 12: Terminal / Shell
- [ ] Create `ui/terminal.lua`
- [ ] **LEARN**: `vim.fn.termopen()` and terminal buffer lifecycle
- [ ] Implement `S` for `docker exec -it` shell/command modes

### Phase 13: Images View
- [ ] Create `ui/views/images.lua`
- [ ] Tree model + expand/collapse state
- [ ] Actions: `o`, `d`, `P` (prune)

### Phase 14: Networks View
- [ ] Create `ui/views/networks.lua`
- [ ] Tree model with connected containers
- [ ] Actions: expand/collapse + remove

### Phase 15: LogLens Core Engine (performance-first)
- [ ] Create `ui/loglens/init.lua`
- [ ] Add source adapters: docker stdout/stderr + file tail
- [ ] Add stream framer (newline + JSON entry boundaries)
- [ ] Implement ring buffer + batched flush renderer
- [ ] Implement follow mode + pause/freeze toggle

### Phase 16: LogLens Parsing, Formatting, Highlighting
- [ ] Create `ui/loglens/parsers.lua` (`plain`, `json`, custom hook)
- [ ] Create `ui/loglens/formatters.lua` (raw, compact, pretty)
- [ ] Create `ui/loglens/highlighters.lua` (level, keyword, regex)
- [ ] Per-container/per-source config rules in `config.lua`
- [ ] Detail popup: parsed/raw toggle + copy/yank support

### Phase 17: Auto-Refresh, Help, and UX Polish
- [ ] **LEARN**: `vim.loop` timers
- [ ] Implement refresh interval lifecycle (start/stop on open/close)
- [ ] Create `ui/popups/help.lua` and `?` overlay
- [ ] Loading/empty/error states for each view

### Phase 18: Commands, Health Check, and Final Cleanup
- [ ] Create `health.lua`
- [ ] Validate Docker CLI/daemon availability
- [ ] Verify all commands (`:Dockyard`, `:DockyardFull`, LogLens entrypoints)
- [ ] Final refactor + docs sync

---

## Dependencies

### Required
- **Neovim >= 0.7**
- **plenary.nvim** - Async job execution
- **Docker CLI** - Must be in PATH
- **Docker daemon** - Must be running

### Optional
- **toggleterm.nvim** - Persistent terminal sessions

---

## Milestones

| After Phase | Result |
|-------------|--------|
| 0-1 | Plugin loads, shows notification |
| 2-3 | Can fetch and store Docker data |
| 4-7 | Basic UI with table rendering |
| **8-10** | **Fully working Containers tab** |
| 11-12 | All three tabs working |
| 13-16 | Advanced features complete |
| 17-18 | Production-ready plugin |

---

## Notes

- The backup folder (`dockyard.nvim.bak/`) contains the original AI-generated implementation for reference
- Focus on understanding each Lua concept before moving forward
- Each phase builds on the previous - don't skip ahead
- Test frequently by reloading Neovim (`:source %` or restart)
