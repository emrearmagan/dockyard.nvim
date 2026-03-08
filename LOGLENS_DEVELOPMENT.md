# LogLens Development Plan

## Overview

LogLens is the log viewing subsystem for dockyard.nvim. It provides a split-screen interface to view, parse, and filter container logs from multiple sources.

---

## What is LogLens?

Think of LogLens like a "magnifying glass" for your Docker container logs. Instead of running `docker logs` in a terminal and scrolling through walls of text, LogLens:

1. **Opens a dedicated split** - Logs appear in their own window, side by side with your Dockyard dashboard
2. **Parses different formats** - Whether your app outputs JSON, plain text, or custom formats, LogLens understands them
3. **Highlights important info** - Errors are red, warnings are yellow, timestamps are blue - at a glance you know what matters
4. **Lets you filter** - Only want to see errors? Type `/error` and everything else hides

---

## Core Concepts

### 1. Log Sources

A "source" is WHERE the logs come from. There are different types:

| Source Type | Description | Example Command |
|-------------|-------------|-----------------|
| **docker** | Container stdout/stderr | `docker logs -f --tail 100 my_container` |
| **file** | Log file inside container | `docker exec my_container tail -f /var/log/app.log` |
| **compose** | Docker Compose logs | `docker compose logs -f service_name` |

**Why does this matter?**  
Different applications write logs differently. A Node.js app might write to stdout, while an Nginx container might write to `/var/log/nginx/access.log`. LogLens needs to know where to get the logs.

### 2. Log Formats

A "format" is HOW the logs are structured:

| Format | Example |
|--------|---------|
| **Plain text** | `2024-01-15 10:30:45 INFO Server started on port 3000` |
| **JSON** | `{"level":"info","timestamp":"2024-01-15T10:30:45Z","message":"Server started","port":3000}` |
| **Structured text** | `[2024-01-15 10:30:45] [INFO] [server] Server started on port 3000` |

**Why does this matter?**  
JSON logs are easy for machines but hard for humans. Plain text is easy to read but hard to filter. LogLens parsers convert any format into a consistent structure we can display and filter.

### 3. The Pipeline

Every log line flows through a pipeline:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         THE LOGLENS PIPELINE                            │
└─────────────────────────────────────────────────────────────────────────┘

   ┌─────────┐      ┌─────────┐      ┌───────────┐      ┌─────────────┐
   │  SOURCE │ ──▶  │  FRAME  │ ──▶  │   PARSE   │ ──▶  │  HIGHLIGHT  │
   │         │      │         │      │           │      │             │
   │ Docker  │      │ Split   │      │ Extract   │      │ Color code  │
   │ logs,   │      │ stream  │      │ level,    │      │ by level,   │
   │ Files,  │      │ into    │      │ message,  │      │ keywords,   │
   │ etc.    │      │ entries │      │ timestamp │      │ patterns    │
   └─────────┘      └─────────┘      └───────────┘      └─────────────┘
                                           │
                                           ▼
                                    ┌─────────────┐
                                    │   RENDER    │
                                    │             │
                                    │ Display in  │
                                    │ the buffer  │
                                    └─────────────┘
```

**Step by step:**
1. **Source** - We start a streaming process (like `docker logs -f`)
2. **Frame** - Raw data arrives in chunks; we split it into individual log entries
3. **Parse** - Each entry becomes a structured object `{level, message, timestamp, raw}`
4. **Highlight** - We determine colors/highlights based on content
5. **Render** - We display the formatted, highlighted logs in the buffer

---

## Architecture Design

### File Structure

```
lua/dockyard/ui/loglens/
├── init.lua          # Public API: open(), close(), is_open()
├── state.lua         # LogLens state: buf_id, win_id, entries, config
├── sources/          # Where logs come from
│   ├── init.lua      # Source factory
│   ├── docker.lua    # Docker logs source
│   └── file.lua      # File tail source
├── parsers/          # How to understand log formats
│   ├── init.lua      # Parser factory
│   ├── json.lua      # JSON log parser
│   └── text.lua      # Plain text parser
├── components/       # UI building blocks
│   ├── header.lua    # Container name + action buttons
│   └── entries.lua   # Log entries renderer
└── highlights.lua    # Log-specific highlight groups
```

### Why This Structure?

**Separation of concerns** - Each file does ONE thing:
- `sources/` knows HOW to get logs, but doesn't care about format
- `parsers/` knows HOW to parse formats, but doesn't care where logs come from
- `components/` knows HOW to display, but doesn't care about parsing

**Easy to extend** - Want to add a new source (e.g., Kubernetes)? Add `sources/kubernetes.lua`. Want a new parser (e.g., Apache logs)? Add `parsers/apache.lua`.

---

## Configuration Design

Users configure LogLens per-container:

```lua
-- In setup()
require("dockyard").setup({
    loglens = {
        -- Global settings
        max_lines = 2000,        -- Memory limit
        follow = true,           -- Auto-scroll by default
        
        -- Per-container settings
        containers = {
            ["my-api"] = {
                -- This container has multiple log sources
                sources = {
                    {
                        name = "Application Logs",
                        type = "docker",     -- Use docker logs
                        parser = "json",     -- Parse as JSON
                        fields = {           -- Which JSON fields to show
                            level = "level",
                            message = "message",
                            timestamp = "timestamp",
                        },
                    },
                    {
                        name = "Nginx Access",
                        type = "file",
                        path = "/var/log/nginx/access.log",
                        parser = "text",
                    },
                },
            },
            
            ["my-worker"] = {
                -- Simple container - just use defaults
                sources = {
                    { type = "docker" }  -- Auto-detect format
                },
            },
        },
    },
})
```

### Configuration Inheritance

```
Global defaults → Container defaults → Source config
```

If a container has no config, LogLens uses sensible defaults:
- Source: docker stdout/stderr
- Parser: auto-detect (JSON if starts with `{`, else text)
- Fields: standard JSON fields (level, message, timestamp)

---

## Development Phases

| Phase | Goal | Key Learning |
|-------|------|--------------|
| **Phase 1** | Split screen opens and closes | Neovim split windows |
| **Phase 2** | UI with header + fake data | Buffer rendering, winbar |
| **Phase 3** | Configuration system | Deep table merging, validation |
| **Phase 4** | Parser architecture | Pattern matching, JSON handling |
| **Phase 5** | Custom highlighting | Vim syntax, extmarks |

Each phase builds on the previous. Don't skip ahead!

---

## Key Decisions

### 1. Why Split Windows Instead of Floating?

The main Dockyard dashboard uses floating windows because it's an overlay - you open it, do something, close it. LogLens is different:

- **Logs are persistent** - You want to watch them while doing other things
- **Logs are tall** - You need vertical space to see history
- **Context matters** - Seeing the container list alongside logs is useful

A horizontal split below the main dashboard gives you both.

### 2. Why Separate Parsers from Sources?

Consider these scenarios:

| Source | Format |
|--------|--------|
| Docker stdout | JSON |
| Docker stdout | Plain text |
| File in container | JSON |
| File in container | Custom format |

The source (docker vs file) is independent of the format (JSON vs text). By separating them, we get:

```
Sources: docker, file         = 2 modules
Parsers: json, text, custom   = 3 modules
Combinations: 2 × 3           = 6 possibilities with only 5 modules!
```

If we combined them, we'd need 6 modules. This is called the "Strategy Pattern".

### 3. Why Ring Buffer for Log Storage?

Logs are infinite - containers can run for months. We can't store everything in memory. A "ring buffer" is like a circular queue:

```
Max size: 5 entries

Add 1: [1, _, _, _, _]
Add 2: [1, 2, _, _, _]
Add 3: [1, 2, 3, _, _]
Add 4: [1, 2, 3, 4, _]
Add 5: [1, 2, 3, 4, 5]
Add 6: [6, 2, 3, 4, 5]  ← Entry 1 is overwritten!
Add 7: [6, 7, 3, 4, 5]  ← Entry 2 is overwritten!
```

We always keep the most recent N entries.

### 4. Why Debounced Rendering?

When logs stream quickly (100+ lines/second), we can't re-render after each line - Neovim would freeze. Instead:

```
Line arrives → Add to queue → Timer fires every 50ms → Render all queued lines
```

This batches updates: instead of 100 renders, we do 2 (one every 50ms for 100ms of logs).

---

## What We Learned from the Backup

The old `loglens.lua` had good ideas but bad implementation:

### Good Ideas to Keep

1. **Multi-source configuration** - Containers can have multiple log sources
2. **Buffer reuse** - Don't create duplicate buffers for the same container
3. **Follow mode with auto-disable** - Stop following when user scrolls up
4. **Parser fallback chain** - Custom → JSON detect → Text
5. **Debounced rendering** - Batch updates for performance
6. **Proper cleanup** - Stop processes when buffer closes
7. **Max lines limit** - Prevent memory bloat

### Bad Patterns to Avoid

1. **Monolithic functions** - The old `M.open()` was 376 lines!
2. **Local state in closures** - Impossible to inspect or test
3. **Deprecated APIs** - Use `vim.bo[buf]` not `nvim_buf_set_option`
4. **Magic numbers** - Use named constants
5. **External dependencies** - Don't require `jq`, use pure Lua
6. **Hardcoded layout** - Make window position configurable

---

## What We Learned from log-highlight.nvim

This plugin uses Vim's syntax highlighting, which is pattern-based:

```vim
" Match timestamps like 12:34:56
syn match LogTime '\d\{2}:\d\{2}:\d\{2}'

" Match log levels
syn keyword LogLvError ERROR Error error ERR Err err

" Link syntax groups to highlight groups
hi def link LogLvError ErrorMsg
```

**Key insights:**

1. **Patterns are powerful** - Regex can match dates, IPs, UUIDs, paths
2. **Keywords are fast** - For exact matches like ERROR, use `syn keyword`
3. **Groups are composable** - Define patterns, link to highlight groups
4. **User customization** - Let users add their own keywords

For LogLens, we'll use a hybrid approach:
- **Structured highlighting** for parsed logs (we know the level, timestamp)
- **Pattern highlighting** for raw/text logs (regex for common patterns)

---

## Next Steps

Start with **Phase 1** - getting a split window to open when you press a key on a container. This is the foundation everything else builds on.

See: `LOGLENS_PHASE_1.md`
