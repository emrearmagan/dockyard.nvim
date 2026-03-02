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
M.open()          -- Open in vertical split
M.open_full()     -- Open in new tab  
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
M.win_id = nil         -- Current window ID
M.buf_id = nil         -- Current buffer ID
M.current_view = "containers"  -- Active tab
M.line_to_item = {}    -- Maps buffer line -> data item for actions
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

---

## Development Phases

### Phase 0: Lua Fundamentals & First Plugin
- [ ] Clear folder and create structure
- [ ] **LEARN**: Variables, types (string, number, boolean, nil)
- [ ] Create `plugin/dockyard.lua` with `vim.notify("Hello!")`
- [ ] **LEARN**: Tables (arrays and dictionaries)
- [ ] **LEARN**: Functions, local scope, return values
- [ ] **LEARN**: Control flow (if/else, for loops with pairs/ipairs)
- [ ] **LEARN**: Modules, require(), M = {} pattern

### Phase 1: Config & Setup Pattern
- [ ] Create `config.lua` with defaults
- [ ] **LEARN**: `vim.tbl_deep_extend()` for merging tables
- [ ] Create `init.lua` with `setup(opts)`
- [ ] Test by notifying config values

### Phase 2: Docker Module (CLI Wrapper)
- [ ] **LEARN**: `plenary.job` for async commands
- [ ] Create `docker.lua` with module pattern
- [ ] Implement `list_containers(callback)` with result pattern
- [ ] **LEARN**: `vim.json.decode()` and `pcall()` for error handling
- [ ] Add `list_images()`, `list_networks()`
- [ ] Add `container_action()`, `inspect()`

### Phase 3: State Management
- [ ] Create `state/containers.lua` with local state
- [ ] **LEARN**: Closures
- [ ] Add `refresh()`, `get_all()`, `get_by_id()`, `is_running()`
- [ ] Create `state/images.lua`, `state/networks.lua`

### Phase 4: UI Foundation
- [ ] **LEARN**: `vim.api.nvim_*` functions
- [ ] Create `ui/state.lua`
- [ ] Create `ui/init.lua` with `open()` (vsplit + buffer)
- [ ] **LEARN**: Buffer options (buftype, modifiable)
- [ ] Implement `close()`, `is_open()`

### Phase 5: Colors & Highlighting
- [ ] **LEARN**: `vim.api.nvim_set_hl()`
- [ ] Create `ui/highlights.lua` with color palette
- [ ] Define highlight groups
- [ ] **LEARN**: Extmarks for applying highlights

### Phase 6: Renderer & Layout
- [ ] Create `ui/renderer.lua`
- [ ] **LEARN**: `vim.api.nvim_buf_set_lines()`
- [ ] Create `ui/components/header.lua`
- [ ] Create `ui/components/navbar.lua`
- [ ] **LEARN**: `string.format()`, `string.rep()`

### Phase 7: Table Component
- [ ] Create `ui/components/table.lua`
- [ ] **LEARN**: `vim.fn.strdisplaywidth()` for unicode
- [ ] Implement column width calculation
- [ ] Implement text truncation
- [ ] Return line-to-data mapping

### Phase 8: Containers View
- [ ] Create `ui/views/containers.lua`
- [ ] Define columns: Icon, Name, Image, Status, Ports
- [ ] Transform data into table rows
- [ ] Add status colors

### Phase 9: Keymaps & Navigation
- [ ] Create `ui/keymaps.lua`
- [ ] **LEARN**: `vim.keymap.set()` with buffer option
- [ ] Implement j/k, Tab/S-Tab, q, R
- [ ] Create `get_item_at_cursor()`

### Phase 10: Container Actions
- [ ] Implement s (toggle), x (stop), r (restart)
- [ ] **LEARN**: `vim.ui.select()`, `vim.ui.input()`
- [ ] Implement d (remove with confirmation)
- [ ] Auto-refresh after actions

### Phase 11: Images View
- [ ] Create `ui/views/images.lua`
- [ ] Implement tree with expand/collapse
- [ ] Add o (toggle), d (remove), P (prune)

### Phase 12: Networks View
- [ ] Create `ui/views/networks.lua`
- [ ] Tree with connected containers
- [ ] Add actions

### Phase 13: Inspect Popup
- [ ] Create `ui/popups/inspect.lua`
- [ ] **LEARN**: Floating windows
- [ ] Implement K/Enter to open

### Phase 14: Help Popup
- [ ] Create `ui/popups/help.lua`
- [ ] Implement ? toggle

### Phase 15: Terminal / Shell
- [ ] Create `ui/terminal.lua`
- [ ] **LEARN**: `vim.fn.termopen()`
- [ ] Implement S to open shell

### Phase 16: LogLens
- [ ] Create `ui/loglens/init.lua`
- [ ] Implement L to open logs
- [ ] Stream with follow mode
- [ ] Add filtering
- [ ] Create parsers

### Phase 17: Auto-Refresh & Polish
- [ ] **LEARN**: `vim.loop` timers
- [ ] Implement refresh_interval
- [ ] Add loading states
- [ ] Error handling polish

### Phase 18: Commands & Health Check
- [ ] Create `health.lua`
- [ ] Add `:Dockyard`, `:DockyardFull` commands
- [ ] Final cleanup

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