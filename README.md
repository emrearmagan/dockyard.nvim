[![Neovim](https://img.shields.io/badge/Neovim-0.10+-blue.svg)](https://neovim.io/)
[![Version](https://img.shields.io/github/v/tag/emrearmagan/dockyard.nvim.svg)](https://github.com/emrearmagan/dockyard.nvim/tags)
[![License](https://img.shields.io/github/license/emrearmagan/dockyard.nvim?style=flat-square&color=blue)](LICENSE)

# Dockyard.nvim

Interactive Docker dashboard directly in your editor. It lets you view and manage containers, images, networks, and logs

> [!CAUTION]
> **Still in early development, will have breaking changes!**

<table>
  <thead>
    <tr>
      <th width="50%" align="center">Dockyard</th>
      <th width="50%" align="center">Detail Panel</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td width="50%"><img alt="LogLens" src="https://github.com/user-attachments/assets/75c21845-f245-428a-b73d-0fdb975b6b9f"></td>
      <td width="50%"><img alt="LogLens" src="https://github.com/user-attachments/assets/75c21845-f245-428a-b73d-0fdb975b6b9f"></td>
    </tr>
  </tbody>
</table>

## Introduction

Dockyard provides a single Docker workspace inside Neovim. You can inspect containers, images, and networks, run common container actions, open shell sessions, and stream logs through LogLens without leaving the editor.

## Features

- [x] Inspect and manage containers
- [x] Inspect and manage images
- [x] Inspect and manage networks
- [x] Docker Compose grouping via the `compose` view
- [x] Open shell sessions inside containers
- [x] Stream and inspect logs
- [x] Run Docker build commands from Dockyard
- [ ] Navigate and search the file tree inside a container
- [ ] Copy, modify, and manage files inside a container

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
  <img width="49%" alt="Docker stats" src="https://github.com/user-attachments/assets/1aeb9163-a0e9-4f4a-9243-305f4ba9f5f0" />
  <img width="49%" alt="Networks" src="https://github.com/user-attachments/assets/b0d76760-a09c-432b-899b-47119069caaa" />
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
    default_highlights = { ... } -- Optional global default highlights. Comes with default rules, but you can override them.
  },
})
```

## LogLens

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

> [!NOTE]
> Dockyard comes with some default highlights, but you can override or extend them with your own rules.

## Commands

- `:Dockyard` - open fullscreen UI
- `:DockyardFloat` - open floating UI
- `:DockyardBuild` - build a Docker image from the nearest `Dockerfile`. Tags the image after the parent directory name.
- `:DockyardRun` - runs Docker Compose services (`docker compose up -d --force-recreate`). SUpports visual selection.

## Keymaps

Press `g?` inside any Dockyard buffer to see all bindings for the current view.

Set an action to `false` to disable it, or set it to a list to add aliases.

```lua
require("dockyard").setup({
  keymaps = {
    ui = {
      help = "g?",
      close = "q", -- false would disable it
      refresh = "R",
      next_view = { "<Tab>", "]" }, -- list adds aliases
      prev_view = { "<S-Tab>", "[" },
      toggle_node = "<CR>",
      open_details = "K",
      open_panel = "p",
    },
    containers = {
      toggle_start_stop = "s",
      stop = "x",
      restart = "r",
      remove = "d",
      open_terminal = "T",
      open_logs = "L",
    },
    images = {
      remove = "d",
      prune = "P",
    },
    networks = {
      remove = "d",
    },
    volumes = {
      remove = "d",
    },
    loglens = {
      close = "q",
      toggle_follow = "f",
      toggle_raw = "r",
      filter = "/",
      clear_filter = "c",
      open_detail = { "<CR>", "K" },
      help = "g?",
    },
  },
})
```

## License

MIT - see [LICENSE](LICENSE).
