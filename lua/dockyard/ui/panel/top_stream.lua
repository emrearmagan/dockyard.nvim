local M = {}

local docker = require("dockyard.docker")

---@class TopStreamInstance
---@field container_id string|nil
---@field columns table[]
---@field rows table[]
---@field _timer number|nil
---@field _polling boolean
---@field start fun(self: TopStreamInstance, container_id: string)
---@field stop fun(self: TopStreamInstance)

---Parse raw `docker top` output into columns and rows.
---docker top output is fixed-width space-aligned:
---  UID                 PID                 PPID  ... CMD
---  1000                29404               29381 ... python ...
---
---Column positions are inferred from where each header word starts.
---The last column (CMD) captures the rest of the line.
---@param raw string
---@return table[] columns, table[] rows
local function parse_top_output(raw)
	local lines = {}
	for line in raw:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	if #lines == 0 then
		return {}, {}
	end

	local header_line = lines[1]
	local col_starts = {}
	local col_names = {}
	for pos, name in header_line:gmatch("()(%S+)") do
		table.insert(col_starts, pos)
		table.insert(col_names, name)
	end

	if #col_names == 0 then
		return {}, {}
	end

	local columns = {}
	for _, name in ipairs(col_names) do
		table.insert(columns, { key = name:lower(), name = name })
	end

	local rows = {}
	for i = 2, #lines do
		local line = lines[i]
		if line:match("%S") then
			local row = {}
			for j, col_name in ipairs(col_names) do
				local s = col_starts[j]
				local e = j < #col_names and (col_starts[j + 1] - 1) or #line
				local value = line:sub(s, e):match("^(.-)%s*$") or ""
				row[col_name:lower()] = value
			end
			table.insert(rows, row)
		end
	end

	table.sort(rows, function(a, b)
		return (tonumber(a["c"]) or 0) > (tonumber(b["c"]) or 0)
	end)

	return columns, rows
end

---@param opts? { on_update?: fun(), interval?: number }
---@return TopStreamInstance
function M.create(opts)
	opts = opts or {}
	local interval = opts.interval or 3000

	---@class TopStreamInstance
	local instance = {
		container_id = nil,
		columns = {},
		rows = {},
		_timer = nil,
		_polling = false,
	}

	local function poll()
		if not instance.container_id or instance._polling then
			return
		end

		instance._polling = true
		docker.container_top(instance.container_id, function(result)
			instance._polling = false

			if not result.ok or not result.data then
				return
			end

			local columns, rows = parse_top_output(result.data)
			instance.columns = columns
			instance.rows = rows

			if opts.on_update then
				opts.on_update()
			end
		end)
	end

	---@param container_id string
	function instance:start(container_id)
		self:stop()
		self.container_id = container_id
		self.columns = {}
		self.rows = {}

		poll()
		self._timer = vim.fn.timer_start(interval, function()
			poll()
		end, { ["repeat"] = -1 })
	end

	function instance:stop()
		if self._timer then
			vim.fn.timer_stop(self._timer)
			self._timer = nil
		end
		self._polling = false
	end

	return instance
end

return M
