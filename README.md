# Dockyard.nvim

Interactive Docker dashboard directly in your editor. It lets you view and manage containers, images, networks, and logs

> [!CAUTION]
> **Still in early development, will have breaking changes!**

<video src="https://github.com/user-attachments/assets/780cdcf1-5bee-4468-9cd9-7a3ffcdad192" controls width="600"></video>

## Introduction

Dockyard provides a single Docker workspace inside Neovim. You can inspect containers, images, and networks, run common container actions, open shell sessions, and stream logs through LogLens without leaving the editor.

## Requirements

- Neovim `>= 0.9`
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

```lua
require("dockyard").setup({
  loglens = {
    containers = {
      ["api"] = {
        sources = {
          {
            name = "App JSON",
            path = "/var/log/app.json",
            parser = "json",

            _order = { "time", "level", "message" },
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
      ["postgres"] = {
        sources = {
          {
            name = "Docker Logs",
            _order = { "logs" },
            format = function(line)
              return { logs = line }
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
- `path` string (optional; when set, logs are read from that file inside the container)
- `parser` `"json" | "text"`
- `_order` `string[]` (optional column order)
- `format` function (required)
- `highlights` rules (optional)
- `max_lines` number (optional, default `1000`)
- `tails` number (optional, default `100`)

#### Text parser

For text parser, `format` receives a string line.

```lua
{
  name = "Postgres Logs",
  parser = "text",
  _order = { "logs" },
  format = function(line)
    return {
      logs = line,
    }
  end,
}
```

#### JSON parser

For JSON parser, `format` receives a decoded table.

```lua
{
  name = "Backend JSON",
  path = "/var/log/backend.json",
  parser = "json",
  max_lines = 2000,
  tails = 150,

  _order = { "time", "level", "message", "context" },
  format = function(entry)
    local ts = entry.timestamp and entry.timestamp:sub(12, 19) or "--:--:--"
    local level = (entry.level or "info"):upper()
    local ctx = entry.context or {}
    local user = ctx.user_id or "-"
    local trace = entry.trace_id or ctx.trace_id or "-"
    return {
      time = ts,
      level = level,
      message = entry.message or "",
      context = string.format("user=%s trace=%s", user, trace),
    }
  end,
}
```

## Highlight Rules

Rules use Lua patterns.

```lua
highlights = {
  { pattern = "%d%d:%d%d:%d%d", group = "Comment" },
  { pattern = "%f[%a]ERROR%f[^%a]", group = "ErrorMsg" },
  { pattern = "%f[%a]WARN%f[^%a]", group = "WarningMsg" },
  { pattern = "%f[%a]INFO%f[^%a]", group = "Identifier" },
  { pattern = "%d+%.%d+%.%d+%.%d+", group = "Special" },
  { pattern = "/api/[%w_/%-%.]+", color = "#8be9fd" },
}
```

Each rule supports:

- `pattern` (required)
- `group` (highlight group)
- `color` (hex color)

## Commands

- `:Dockyard` - open fullscreen UI
- `:DockyardFloat` - open floating UI

## Keymaps

### Main UI

| Context | Key | Action |
|---|---|---|
| Global | `q` | Close Dockyard |
| Global | `R` | Refresh current tab |
| Global | `<Tab>` / `<S-Tab>` | Next / previous tab |
| Global | `j` / `k` | Move cursor |
| Global | `K` | Open details popup |
| Global | `?` | Open help popup |
| Containers | `s` | Toggle start / stop |
| Containers | `x` | Stop container |
| Containers | `r` | Restart container |
| Containers | `d` | Remove container |
| Containers | `T` | Open shell |
| Containers | `L` | Open LogLens |
| Images | `<CR>` | Expand / collapse |
| Images | `d` | Remove image |
| Images | `P` | Prune dangling images |
| Networks | `<CR>` | Expand / collapse |
| Networks | `d` | Remove network |

### LogLens

| Key | Action |
|---|---|
| `q` | Close LogLens |
| `f` | Toggle follow |
| `r` | Toggle raw mode |
| `/` | Set filter |
| `c` | Clear filter |
| `<CR>` / `K` | Open entry popup |

## License

MIT - see [LICENSE](LICENSE).
