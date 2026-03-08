# LogLens Step 1 (Concrete): Config -> Stream -> Parser -> Table Rows

This version is explicit: every step shows exactly what file to edit and the code to add/replace.

## Rule for this phase

- `format(entry)` must return a **row table**
- renderer uses `table.lua`
- no highlighting logic
- no `auto` parser
- no custom parser function
- user config stays minimal: no `max_lines`, no `tail`, no `follow`

---

## Step 1 - Update `state.lua` (row-based state)

**File:** `lua/dockyard/loglens/state.lua`  
**Do this:** Replace file with:

```lua
---@class LogLensParserSession
---@field push fun(self: LogLensParserSession, chunk: string): table[]
---@field flush fun(self: LogLensParserSession): table[]

---@class LogLensStateData
---@field win_id number|nil
---@field buf_id number|nil
---@field container Container|nil
---@field container_name string|nil
---@field follow boolean
---@field raw boolean
---@field entries table[]
---@field line_map table|nil
---@field job_id number|nil
---@field active_source LogSource|nil
---@field max_lines number
---@field parser_session LogLensParserSession|nil

---@class LogLensState: LogLensStateData
---@field reset fun()
---@field is_open fun(): boolean
---@field has_valid_buffer fun(): boolean

---@type LogLensStateData
local M = {
	win_id = nil,
	buf_id = nil,
	container = nil,
	container_name = nil,

	follow = true,
	raw = false,

	entries = {},
	line_map = nil,

	job_id = nil,
	active_source = nil,
	max_lines = 2000,
	parser_session = nil,
}

---@cast M LogLensState

function M.reset()
	M.win_id = nil
	M.buf_id = nil
	M.container = nil
	M.container_name = nil

	M.follow = true
	M.raw = false

	M.entries = {}
	M.line_map = nil

	M.job_id = nil
	M.active_source = nil
	M.max_lines = 2000
	M.parser_session = nil
end

---@return boolean
function M.is_open()
	return M.win_id ~= nil and vim.api.nvim_win_is_valid(M.win_id)
end

---@return boolean
function M.has_valid_buffer()
	return M.buf_id ~= nil and vim.api.nvim_buf_is_valid(M.buf_id)
end

return M
```

Why: state now stores table rows + parser/stream runtime.

---

## Step 2 - Create `config.lua` resolver + validation

**File:** `lua/dockyard/loglens/config.lua`  
**Do this:** Create file with:

```lua
local dockyard_config = require("dockyard.config")

local M = {}
local DEFAULT_MAX_LINES = 2000
local DEFAULT_TAIL = 100

---@class LogLensRuntime
---@field source LogSource
---@field max_lines number
---@field tail number

---@param name string|nil
---@return string
function M.normalize_container_name(name)
	return tostring(name or ""):gsub("^/", "")
end

---@param container_name string
---@return ContainerLogConfig|nil
function M.get_container_config(container_name)
	local opts = dockyard_config.options.loglens or {}
	local containers = opts.containers or {}
	return containers[container_name]
end

---@param source LogSource
---@return boolean
---@return string|nil
function M.validate_source(source)
	if not source then
		return false, "Missing source config"
	end
	if source.type ~= "docker" and source.type ~= "file" then
		return false, "source.type must be 'docker' or 'file'"
	end
	if source.type == "file" and not source.path then
		return false, "file source needs source.path"
	end
	if source.parser ~= "text" and source.parser ~= "json" then
		return false, "source.parser must be 'text' or 'json'"
	end
	if type(source.format) ~= "function" then
		return false, "source.format(entry) is required"
	end
	return true, nil
end

---@param container Container
---@return number
local function resolve_max_lines(container)
	return DEFAULT_MAX_LINES
end

---@param container Container
---@return number
local function resolve_tail(container)
	return DEFAULT_TAIL
end

---@param container Container
---@return LogLensRuntime|nil
---@return string|nil
function M.resolve_runtime(container)
	local name = M.normalize_container_name(container.name)
	local cfg = M.get_container_config(name)
	if not (cfg and cfg.sources and #cfg.sources > 0) then
		return nil, string.format("No sources configured for container '%s'", name)
	end

	local source = cfg.sources[1]
	local ok, err = M.validate_source(source)
	if not ok then
		return nil, err
	end

	return {
		source = source,
		max_lines = resolve_max_lines(container),
		tail = resolve_tail(container),
	}, nil
end

return M
```

Why: one place to resolve/validate source contract.

Note: `max_lines` and `tail` in this phase are internal defaults (`DEFAULT_MAX_LINES`, `DEFAULT_TAIL`).
They are not part of user plugin config.

---

## Step 3 - Create `stream.lua`

**File:** `lua/dockyard/loglens/stream.lua`  
**Do this:** Create file with:

```lua
local M = {}

---@param container Container
---@param source LogSource
---@param tail number
---@return string[]
local function build_command(container, source, tail)
	tail = tail or 100
	if source.type == "file" then
		return { "docker", "exec", container.id, "tail", "-n", tostring(tail), "-f", source.path }
	end
	return { "docker", "logs", "-f", "--tail", tostring(tail), container.id }
end

---@param data string[]|nil
---@param on_chunk fun(chunk: string)
local function emit_chunk(data, on_chunk)
	if not data or #data == 0 then
		return
	end
	local chunk = table.concat(data, "\n")
	if chunk ~= "" then
		on_chunk(chunk)
	end
end

---@param container Container
---@param source LogSource
---@param tail number
---@param on_chunk fun(chunk: string)
---@param on_exit fun()|nil
---@return number|nil
function M.start(container, source, tail, on_chunk, on_exit)
	local cmd = build_command(container, source, tail)
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data) emit_chunk(data, on_chunk) end,
		on_stderr = function(_, data) emit_chunk(data, on_chunk) end,
		on_exit = function() if on_exit then on_exit() end end,
	})
	if type(job_id) ~= "number" or job_id <= 0 then
		return nil
	end
	return job_id
end

---@param job_id number|nil
function M.stop(job_id)
	if job_id and job_id > 0 then
		pcall(vim.fn.jobstop, job_id)
	end
end

return M
```

Why: isolate process management from parsing/UI.

---

## Step 4 - Create text parser session

**File:** `lua/dockyard/loglens/parsers/text.lua`  
**Do this:** Create file with:

```lua
local M = {}

---@param source LogSource
---@param entry table
---@return table|nil
local function format_row(source, entry)
	local ok, row = pcall(source.format, entry)
	if not ok or type(row) ~= "table" then
		return nil
	end
	return row
end

---@param source LogSource
---@return LogLensParserSession
function M.create(source)
	local pending = ""
	---@type LogLensParserSession
	local session = {}

	---@param chunk string
	---@return table[]
	function session:push(chunk)
		pending = pending .. chunk
		local rows = {}
		while true do
			local idx = pending:find("\n", 1, true)
			if not idx then break end
			local line = pending:sub(1, idx - 1)
			pending = pending:sub(idx + 1)
			local row = format_row(source, { raw = line, message = line })
			if row then table.insert(rows, row) end
		end
		return rows
	end

	---@return table[]
	function session:flush()
		if pending == "" then return {} end
		local line = pending
		pending = ""
		local row = format_row(source, { raw = line, message = line })
		if row then return { row } end
		return {}
	end

	return session
end

return M
```

Why: handles chunk splits and returns row tables.

---

## Step 5 - Create JSON parser session (multiline-safe)

**File:** `lua/dockyard/loglens/parsers/json.lua`  
**Do this:** Create file with:

```lua
local M = {}

---@param source LogSource
---@return LogFieldMapping
local function fields(source)
	return source.fields or { level = "level", message = "message", timestamp = "timestamp" }
end

---@param source LogSource
---@param raw string
---@return table|nil
local function parse_and_format(source, raw)
	local ok, decoded = pcall(vim.json.decode, raw)
	if not ok or type(decoded) ~= "table" then return nil end
	local map = fields(source)
	local entry = {
		raw = raw,
		data = decoded,
		level = decoded[map.level or "level"],
		message = decoded[map.message or "message"],
		timestamp = decoded[map.timestamp or "timestamp"],
	}
	local ok_fmt, row = pcall(source.format, entry)
	if not ok_fmt or type(row) ~= "table" then return nil end
	return row
end

---@param source LogSource
---@return LogLensParserSession
function M.create(source)
	local buffer = ""
	---@type LogLensParserSession
	local session = {}

	---@param chunk string
	---@return table[]
	function session:push(chunk)
		buffer = buffer .. chunk .. "\n"
		local rows = {}
		local i, len = 1, #buffer
		local started, start_idx, depth = false, 1, 0
		local in_string, escape_next = false, false

		while i <= len do
			local ch = buffer:sub(i, i)
			if not started then
				if ch == "{" or ch == "[" then
					started, start_idx, depth = true, i, 1
				end
			else
				if in_string then
					if escape_next then
						escape_next = false
					elseif ch == "\\" then
						escape_next = true
					elseif ch == '"' then
						in_string = false
					end
				else
					if ch == '"' then
						in_string = true
					elseif ch == "{" or ch == "[" then
						depth = depth + 1
					elseif ch == "}" or ch == "]" then
						depth = depth - 1
						if depth == 0 then
							local record = buffer:sub(start_idx, i)
							local row = parse_and_format(source, record)
							if row then table.insert(rows, row) end
							buffer = buffer:sub(i + 1)
							len, i = #buffer, 0
							started, start_idx, depth = false, 1, 0
							in_string, escape_next = false, false
						end
					end
				end
			end
			i = i + 1
		end

		return rows
	end

	---@return table[]
	function session:flush()
		local trimmed = buffer:gsub("^%s+", ""):gsub("%s+$", "")
		buffer = ""
		if trimmed == "" then return {} end
		local row = parse_and_format(source, trimmed)
		if row then return { row } end
		return {}
	end

	return session
end

return M
```

Why: handles multiline JSON reliably with brace/string state machine.

---

## Step 6 - Create parser factory

**File:** `lua/dockyard/loglens/parsers/init.lua`  
**Do this:** Create file with:

```lua
local text_parser = require("dockyard.loglens.parsers.text")
local json_parser = require("dockyard.loglens.parsers.json")

local M = {}

---@param source LogSource
---@return LogLensParserSession|nil
---@return string|nil
function M.create_session(source)
	if source.parser == "text" then
		return text_parser.create(source), nil
	end
	if source.parser == "json" then
		return json_parser.create(source), nil
	end
	return nil, "Unsupported parser. Use 'text' or 'json'"
end

return M
```

Why: single entry point for parser session creation.

---

## Step 7 - Update renderer to table renderer

**File:** `lua/dockyard/loglens/ui/renderer.lua`  
**Do this:** Replace file with:

```lua
local header = require("dockyard.loglens.ui.header")
local table_renderer = require("dockyard.ui.components.table")

local M = {}

---@param rows table[]
---@return table[]
local function infer_columns(rows)
	local first = rows[1]
	if type(first) ~= "table" then
		return { { key = "message", name = "Message" } }
	end

	local cols = {}
	for key, _ in pairs(first) do
		table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
	end
	table.sort(cols, function(a, b)
		return tostring(a.key) < tostring(b.key)
	end)

	if #cols == 0 then
		return { { key = "message", name = "Message" } }
	end

	return cols
end

---@param state LogLensState
---@return boolean
local function is_valid_state(state)
	return state.buf_id ~= nil
		and vim.api.nvim_buf_is_valid(state.buf_id)
		and state.win_id ~= nil
		and vim.api.nvim_win_is_valid(state.win_id)
end

---@param state LogLensState
function M.render(state)
	if not is_valid_state(state) then return end

	local winbar = header.render(state.container_name or "unknown", {
		follow = state.follow,
		raw = state.raw,
	})
	vim.api.nvim_set_option_value("winbar", winbar, { win = state.win_id })

	local columns = infer_columns(state.entries)
	local width = vim.api.nvim_win_get_width(state.win_id)
	local lines, line_map = table_renderer.render({
		columns = columns,
		rows = state.entries,
		width = width,
		margin = 1,
	})

	vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
	vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })

	state.line_map = line_map
	vim.api.nvim_win_set_cursor(state.win_id, { vim.api.nvim_buf_line_count(state.buf_id), 0 })
end

return M
```

Why: rows come from parsers, columns are inferred internally from row keys.

---

## Step 8 - Update `init.lua` orchestration

**File:** `lua/dockyard/loglens/init.lua`  
**Do this:** Update imports and runtime helpers.

### 8.1 Replace imports at top

```lua
local state = require("dockyard.loglens.state")
local renderer = require("dockyard.loglens.ui.renderer")
local ui_state = require("dockyard.ui.state")
local keymaps = require("dockyard.loglens.keymaps")
local loglens_config = require("dockyard.loglens.config")
local parser_factory = require("dockyard.loglens.parsers")
local stream = require("dockyard.loglens.stream")
```

Remove any `fake_data` import/usage.

### 8.2 Add helpers below window creation

```lua
local function stop_stream()
	stream.stop(state.job_id)
	state.job_id = nil
end

local function trim_entries()
	while #state.entries > state.max_lines do
		table.remove(state.entries, 1)
	end
end

local function append_rows(rows)
	for _, row in ipairs(rows or {}) do
		table.insert(state.entries, row)
	end
	trim_entries()
	renderer.render(state)
end

local function flush_parser_session()
	if not state.parser_session then return end
	local rows = state.parser_session:flush()
	if #rows > 0 then append_rows(rows) end
end

---@param container Container
---@return number|nil
local function setup_runtime(container)
	local runtime, err = loglens_config.resolve_runtime(container)
	if not runtime then
		vim.notify("LogLens: " .. tostring(err), vim.log.levels.ERROR)
		return nil
	end

	local session, parser_err = parser_factory.create_session(runtime.source)
	if not session then
		vim.notify("LogLens: " .. tostring(parser_err), vim.log.levels.ERROR)
		return nil
	end

	state.container = container
	state.container_name = loglens_config.normalize_container_name(container.name)
	state.entries = {}
	state.line_map = nil
	state.active_source = runtime.source
	state.max_lines = runtime.max_lines
	state.parser_session = session

	renderer.render(state)
	return runtime.tail
end

local function start_container_stream(container, tail)
	local source = state.active_source
	local session = state.parser_session
	if not source or not session then return end

	stop_stream()
	state.job_id = stream.start(container, source, tail, function(chunk)
		local rows = session:push(chunk)
		if #rows > 0 then append_rows(rows) end
	end, function()
		flush_parser_session()
	end)
end
```

### 8.3 Replace container-switch block in `M.open`

Find this block in `M.open` and replace with:

```lua
local current_id = state.container and state.container.id or nil
if current_id ~= container.id then
	flush_parser_session()
	stop_stream()

	local tail = setup_runtime(container)
	if not tail then
		return
	end

	start_container_stream(container, tail)
end
```

### 8.4 Update `M.close`

At top of `M.close`, add:

```lua
flush_parser_session()
stop_stream()
```

Why: don’t lose buffered partial parser state.

---

## Config example you should use now

```lua
loglens = {
	containers = {
		["shnt-backend-dev"] = {
			sources = {
				{
					name = "Backend JSON",
					type = "file",
					path = "/var/log/backend.json",
					parser = "json",
					format = function(entry)
						local ts = entry.timestamp and entry.timestamp:sub(12, 19) or "--:--:--"
						local lvl = (entry.level or "info"):upper()
						return {
							time = ts,
							level = lvl,
							message = entry.message or "",
						}
					end,
				},
			},
		},
	},
}
```

---

## Final checklist

1. `state.entries` contains row tables
2. `format(entry)` returns row tables
3. parser session emits rows (not strings)
4. renderer uses table renderer with inferred columns
5. stream switch/close properly flushes + stops
