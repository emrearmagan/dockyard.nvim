# Dockyard.nvim

A powerful and interactive Docker management tool for Neovim, designed for a fast and efficient development workflow.

> [!CAUTION]
> **Still in early development, will have breaking changes!**

<div>
  <img src="./examples/overview.gif" alt="loading.gif">
</div>

## Features

- **Container Management**: View all containers with status indicators. Start, stop, restart, and remove containers using single-key commands.
- **Image Explorer**: Interactive list of images grouped by repository. Supports removing images and pruning dangling data.
- **Network Topology**: View Docker networks and their connected containers in a structured tree view.
- **LogLens**: Stream logs from containers or specific log files inside containers. Full control over formatting and syntax highlighting.
- **Integrated Shells**: Open a terminal inside any running container directly from the dashboard.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "emrearmagan/dockyard.nvim",
  dependencies = { 
    "nvim-lua/plenary.nvim",
    "akinsho/toggleterm.nvim", -- Optional: for persistent shells
  },
  config = function()
    require("dockyard").setup({
      -- See configuration below
    })
  end,
  cmd = { "Dockyard", "DockyardFloat" },
}
```

## Configuration

### Minimal Setup

```lua
require("dockyard").setup({})
```

With no configuration, LogLens UI works but log sources must be configured per container.

### Full Configuration (Current)

```lua
require("dockyard").setup({
  display = {
    views = { "containers", "images", "networks" },
  },
  loglens = {
    containers = {
      -- Per-container configuration (see examples below)
    },
  },
})
```

## LogLens Configuration

LogLens is config-driven. For each source you define:
- where logs come from (`type`, `path`)
- how logs are parsed (`parser`)
- how each row is displayed (`format(entry) -> table`)

Important:
- Supported parsers now: `"json"` and `"text"`
- `"auto"` is not supported
- `format` must return a row table (not a string)
- You do not need `max_lines`, `tail`, or `follow` in user config

### Example: JSON Logs (Row Table Output)

```lua
containers = {
  ["my-backend"] = {
    sources = {
      {
        name = "Backend Logs",
        type = "file",
        path = "/var/log/backend.json",
        parser = "json",
        _order = { "time", "level", "message", "context" },

        -- format must return a table row
        format = function(entry)
          local ts = entry.timestamp and entry.timestamp:sub(12, 19) or "--:--:--"
          local lvl = (entry.level or "info"):upper()

          local ctx = (entry.data and entry.data.context) or {}
          local user_id = ctx.user_id or "-"
          local trace_id = ctx.trace_id or "-"

          return {
            time = ts,
            level = lvl,
            message = entry.message or "",
            context = string.format("user=%s trace=%s", user_id, trace_id),
          }
        end,

        -- optional for later highlighting phase
        highlights = {
          { pattern = "%d%d:%d%d:%d%d", group = "Comment" },
          { pattern = "%[ERROR%]", group = "ErrorMsg" },
          { pattern = "%[WARN%]", group = "WarningMsg" },
          { pattern = "%[INFO%]", group = "Identifier" },
        },
      },
    },
  },
},
```

### Example: Plain Text Logs

```lua
containers = {
  ["nginx"] = {
    sources = {
      {
        name = "Access Log",
        type = "file",
        path = "/var/log/nginx/access.log",
        parser = "text",
        _order = { "line" },

        format = function(entry)
          return { line = entry.raw or "" }
        end,
      },
    },
  },
},
```

### LogLens Options Reference

#### Source Options

| Option | Type | Description |
|--------|------|-------------|
| `name` | string | Display name for the source |
| `type` | `"docker"` \| `"file"` | Where to get logs |
| `path` | string | File path (required if `type = "file"`) |
| `parser` | `"json"` \| `"text"` | How to parse lines |
| `_order` | `string[]` | Optional display key order |
| `fields` | table | JSON field mapping (see below) |
| `format` | function | Format function: `entry -> row table` |
| `highlights` | table | Optional (used in later highlighting phase) |

#### Parser Types

| Parser | `entry` contains | Use case |
|--------|------------------|----------|
| `"json"` | `.level`, `.message`, `.timestamp`, `.raw`, `.data` | JSON logs |
| `"text"` | `.raw`, `.message` | Plain text logs |

#### JSON Field Mapping

Different logging frameworks use different field names. Use `fields` to map them:

```lua
-- Your JSON: {"lvl":"info","msg":"Hello","ts":"2026-01-01"}
fields = {
  level = "lvl",       -- Maps "lvl" → entry.level
  message = "msg",     -- Maps "msg" → entry.message
  timestamp = "ts",    -- Maps "ts" → entry.timestamp
},
```

#### `_order` (optional)

Use `_order` on source to control column order without defining full column config:

```lua
_order = { "time", "level", "message", "context" }
```

#### Highlight Rules (later phase)

Each rule matches a Lua pattern and applies a color:

```lua
highlights = {
  -- Use Neovim highlight group
  { pattern = "%[ERROR%]", group = "ErrorMsg" },
  { pattern = "%[WARN%]", group = "WarningMsg" },
  
  -- Use custom hex color
  { pattern = "%[CRITICAL%]", color = "#ff0000" },
  { pattern = "https?://[%w%.%-/]+", color = "#8be9fd" },
}
```

#### Common Lua Patterns

| Pattern | Matches | Example |
|---------|---------|---------|
| `%[ERROR%]` | Literal `[ERROR]` | `[ERROR] failed` |
| `%d%d:%d%d:%d%d` | Time HH:MM:SS | `14:32:05` |
| `%d+%.%d+%.%d+%.%d+` | IP address | `192.168.1.1` |
| `https?://[%w%.%-/]+` | URLs | `https://example.com` |
| `'" %d%d%d '` | HTTP status | `" 200 "`, `" 404 "` |

### Multiple Sources per Container

A container can have multiple log sources:

```lua
["my-app"] = {
  sources = {
    {
      name = "Docker Output",
      type = "docker",
      parser = "text",
      _order = { "line" },
      format = function(entry) return { line = entry.raw or "" } end,
      highlights = {},
    },
    {
      name = "App Log",
      type = "file",
      path = "/var/log/app.log",
      parser = "json",
      _order = { "level", "message" },
      format = function(entry)
        return {
          level = tostring(entry.level or "INFO"),
          message = entry.message or "",
        }
      end,
      highlights = {},
    },
  },
},
```

## Commands

| Command | Description |
|---------|-------------|
| `:Dockyard` | Open the UI fullscreen |
| `:DockyardFloat` | Open the UI in a floating window |

## License

MIT License - see [LICENSE](LICENSE) for details.
