local header = require("dockyard.loglens.ui.header")

local M = {}

---@param state LogLensState
---@return boolean
local function is_valid_state(state)
	return state.buf_id ~= nil
		and vim.api.nvim_buf_is_valid(state.buf_id)
		and state.win_id ~= nil
		and vim.api.nvim_win_is_valid(state.win_id)
end

---@param state LogLensState
---@return string[]
---@return table
local function build_lines(state)
	---@type string[]
	local lines = {}
	---@type table
	local line_map = {}

	for _, entry in ipairs(state.entries or {}) do
		table.insert(lines, entry)
		table.insert(line_map, entry)
	end

	return lines, line_map
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

	local lines, line_map = build_lines(state)

	vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
	vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })

	state.line_map = line_map

	local n = vim.api.nvim_buf_line_count(state.buf_id)
	vim.api.nvim_win_set_cursor(state.win_id, { n, 0 })
end

return M
