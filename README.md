# Dockyard.nvim

Interactive Docker dashboard directly in your editor. It lets you view and manage containers, images, networks, and logs

![loglens](https://github.com/user-attachments/assets/2d5121cb-3a79-4cb8-a248-a894bc091e31)

> [!CAUTION]
> **Still in early development, will have breaking changes!**

## Introduction

Dockyard provides a single Docker workspace inside Neovim. You can inspect containers, images, and networks, run common container actions, open shell sessions, and stream logs through LogLens without leaving the editor.

## Features

- [x] Inspect and manage containers
- [x] Inspect and manage images
- [x] Inspect and manage networks
- [x] Docker Compose grouping via the `compose` view
- [x] Open shell sessions inside containers
- [x] Stream and inspect logs
- [ ] Navigate and search the file tree inside a container
- [ ] Copy, modify, and manage files inside a container
- [ ] Run Docker build commands from Dockyard

<video src="https://github.com/user-attachments/assets/780cdcf1-5bee-4468-9cd9-7a3ffcdad192" controls width="600"></video>

## Requirements

- Neovim `>= 0.10`
- Docker CLI available in `$PATH`
- [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)
- [`akinsho/toggleterm.nvim`](https://github.com/akinsho/toggleterm.nvim) (optional, for `T` shell keymap)

## Installation

### lazy.nvim

```lua
{
  "emrearmagan/dockyard.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "akinsho/toggleterm.nvim", -- optional
  },
  cmd = { "Dockyard", "DockyardFloat" },
  lazy = true,
  config = function()
    require("dockyard").setup({})
  end,
}
```

<p align="center">
  <img src="https://github.com/user-attachments/assets/45ea8bb8-ba3d-4152-815c-eceb826d35ac" alt="images" width="49%" />
  <img src="https://github.com/user-attachments/assets/6ac75d4f-e54a-47f4-810a-c3bf331b7f8e" alt="networks" width="49%" />
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/35655c5e-52f6-492e-9359-fdefd853e928" alt="images" width="49%" />
</p>

## Configuration

> [!tip]
> It's a good idea to run `:checkhealth dockyard` to see if everything is set up correctly.

```lua
require("dockyard").setup({
  display = {
    -- Available views: "containers", "compose", "images", "networks", "volumes"
    -- "compose" shows containers grouped by Docker Compose project
    views = { "containers", "images", "networks", "volumes" },
  },
  loglens = {
    containers = {
      -- Override highlights only
      ["postgres"] = {
        highlights = {
          { pattern = "%f[%a]ERROR%f[%A]", group = "ErrorMsg" },
        },
      },
      -- Mix docker logs with file sources
      ["api"] = {
        _order = { "time", "level", "message" },
        sources = {
          { name = "Docker Logs" },   -- stdout/stderr, no path needed
          {
            name = "App Logs",
            path = "/var/log/app.json",
            parser = "json",
            tails = 200,
            format = function(entry)
              return {
                time = entry.timestamp and entry.timestamp:sub(12, 19) or "--:--:--",
                level = (entry.level or "info"):upper(),
                message = entry.message or "",
              }
            end,
          },
        },
      },
    },
  },
})
```

## LogLens

![loglens](https://github.com/user-attachments/assets/2d5121cb-3a79-4cb8-a248-a894bc091e31)

Open LogLens from the containers tab with `L`. Each container can define one or more log sources.

### Source options

- `name` string (optional)
- `path` string (optional) — omit to stream docker stdout/stderr (`docker logs -f`)
- `parser` `"json" | "text"` (defaults to `"text"` when no path)
- `format` function (optional when no path; receives `(entry, ctx)`)
- `tails` number (optional, default `100`)

Container-level defaults (applied to all sources unless overridden):

- `_order` `string[]` (optional column order)
- `format` function
- `highlights` `LogHighlightRule[]` (optional; sensible defaults applied when omitted)
- `max_lines` number (optional, default `1000`)
- `tails` number (optional, default `100`)

If no `sources` are configured for a container, docker logs are streamed automatically.

#### Text parser

For text parser, `format` receives `(line, ctx)`.

```lua
{
  name = "Postgres Logs",
  parser = "text",
  _order = { "logs" },
  format = function(line, ctx)
    return {
      source = ctx.name or "-",
      logs = line,
    }
  end,
}
```

#### JSON parser

For JSON parser, `format` receives `(entry, ctx)` where `ctx` includes source metadata (`name`, `path`, `parser`).

```lua
{
  name = "Backend JSON",
  path = "/var/log/backend.json",
  parser = "json",
  max_lines = 2000,
  tails = 150,

  _order = { "time", "level", "message", "context" },
  format = function(entry, ctx)
    local ts = entry.timestamp and entry.timestamp:sub(12, 19) or "--:--:--"
    local level = (entry.level or "info"):upper()
    local ectx = entry.context or {}
    local user = ectx.user_id or "-"
    local trace = entry.trace_id or ectx.trace_id or "-"
    return {
      time = ts,
      level = level,
      source = ctx.name or "-",
      message = entry.message or "",
      context = string.format("user=%s trace=%s", user, trace),
    }
  end,
  highlights = {
     { pattern = "%d%d:%d%d:%d%d", group = "Comment" },
     { pattern = "%f[%a]ERROR%f[^%a]", group = "ErrorMsg" },
     { pattern = "%f[%a]WARN%f[^%a]", group = "WarningMsg" },
     { pattern = "%f[%a]INFO%f[^%a]", group = "Identifier" },
     { pattern = "%d+%.%d+%.%d+%.%d+", group = "Special" },
     { pattern = "/api/[%w_/%-%.]+", color = "#8be9fd" },
  }
}
```

## Highlight Rules

Each rule supports:

- `pattern` (required)
- `group` (highlight group)
- `color` (hex color)

> [!Notice]
> Dockyard comes with some default highlights, but you can override or extend them with your own rules.

## Commands

- `:Dockyard` - open fullscreen UI
- `:DockyardFloat` - open floating UI
- `:DockyardBuild` - build a Docker image from the nearest `Dockerfile`. Tags the image after the parent directory name.
- `:DockyardRun` - runs Docker Compose services (`docker compose up -d --force-recreate`). SUpports visual selection.

## Keymaps

### Main UI

| Context    | Key                 | Action                    |
| ---------- | ------------------- | ------------------------- |
| Global     | `q`                 | Close Dockyard            |
| Global     | `R`                 | Refresh current tab       |
| Global     | `<Tab>` / `<S-Tab>` | Next / previous tab       |
| Global     | `j` / `k`           | Move cursor               |
| Global     | `p`                 | Open detail panel         |
| Global     | `K`                 | Open details popup        |
| Global     | `<CR>`              | Expand / Collapse         |
| Global     | `?`                 | Open help popup           |
| Containers | `s`                 | Toggle start / stop       |
| Containers | `x`                 | Stop container            |
| Containers | `r`                 | Restart container         |
| Containers | `d`                 | Remove container          |
| Containers | `T`                 | Open shell                |
| Containers | `L`                 | Open LogLens              |
| Images     | `d`                 | Remove image              |
| Images     | `P`                 | Prune unused images       |
| Networks   | `d`                 | Remove network            |
| Volumes    | `d`                 | Remove volume             |
| Volumes    | `K`                 | Open details popup        |
| Volumes    | `o`                 | Open mountpoint in Neovim |

### LogLens

| Key          | Action           |
| ------------ | ---------------- |
| `q`          | Close LogLens    |
| `f`          | Toggle follow    |
| `r`          | Toggle raw mode  |
| `/`          | Set filter       |
| `c`          | Clear filter     |
| `<CR>` / `K` | Open entry popup |

## License

MIT - see [LICENSE](LICENSE).
