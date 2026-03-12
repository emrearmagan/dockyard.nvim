local M = {}

local header = require("dockyard.loglens.ui.header")
local table_renderer = require("dockyard.ui.components.table")
local highlighter = require("dockyard.loglens.ui.highlight")
local ns = vim.api.nvim_create_namespace("dockyard.loglens")

---@param state LogLensState
---@return boolean
local function is_valid_state(state)
	return state.buf_id ~= nil
		and vim.api.nvim_buf_is_valid(state.buf_id)
		and state.win_id ~= nil
		and vim.api.nvim_win_is_valid(state.win_id)
end

---@param rows table[]
---@param order string[]|nil
---@return table[]
---Infer table columns from the first formatted row. Might later be extended to support multiple rows and more complex logic.
---
---If `order` is provided (from `source._order`), keys are taken in that order.
---Otherwise, keys are taken from the first row table.
---
---Examples:
---  row = { time = "12:00:00", level = "INFO", message = "ok" }
---  order = { "time", "level", "message" }
---  -> columns: Time, Level, Message
---
---  row = { message = "ok", level = "INFO" }
---  order = nil
---  -> columns inferred from row keys
local function infer_columns(rows, order)
	local first = rows[1]
	if type(first) ~= "table" then
		return {}
	end

	local cols = {}
	if type(order) == "table" then
		for _, key in ipairs(order) do
			if type(key) == "string" and first[key] ~= nil then
				table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
			end
		end
	else
		for key, _ in pairs(first) do
			table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
		end
	end

	if #cols == 0 then
		return {}
	end

	return cols
end

---@param entries LogLensEntry[]
---@return table[]
local function to_rows(entries)
	local rows = {}
	for _, item in ipairs(entries or {}) do
		if type(item) == "table" and type(item.data) == "table" then
			table.insert(rows, item.data)
		end
	end
	return rows
end

---@param state LogLensState
function M.render(state)
	if not is_valid_state(state) then
		return
	end

	local winbar = header.render(state.container_name or "unknown", {
		follow = state.follow,
		raw = state.raw,
	})
	vim.api.nvim_set_option_value("winbar", winbar, { win = state.win_id })

	local source = state.active_source or {}
	local rows = to_rows(state.entries)
	local columns = infer_columns(rows, source._order)
	if #columns == 0 then
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
		vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, {})
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })
		state.line_map = {}
		return
	end

	local width = vim.api.nvim_win_get_width(state.win_id)
	local lines, line_map = table_renderer.render({
		columns = columns,
		rows = rows,
		width = width,
		margin = 0,
		fill = false,
	})

	vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
	vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })
	highlighter.apply(state.buf_id, ns, lines, line_map, source.highlights or {})

	state.line_map = line_map

	local n = vim.api.nvim_buf_line_count(state.buf_id)
	vim.api.nvim_win_set_cursor(state.win_id, { n, 0 })
end

return M
