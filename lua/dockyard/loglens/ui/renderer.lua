local M = {}

local header = require("dockyard.loglens.ui.header")
local table_renderer = require("dockyard.ui.components.table")

---@param state LogLensState
---@return boolean
local function is_valid_state(state)
	return state.buf_id ~= nil
		and vim.api.nvim_buf_is_valid(state.buf_id)
		and state.win_id ~= nil
		and vim.api.nvim_win_is_valid(state.win_id)
end

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
function M.render(state)
	if not is_valid_state(state) then
		return
	end

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
		fill = false,
	})

	vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
	vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })

	state.line_map = line_map

	local n = vim.api.nvim_buf_line_count(state.buf_id)
	vim.api.nvim_win_set_cursor(state.win_id, { n, 0 })
end

return M
