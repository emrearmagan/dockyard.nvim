---@class LogLensStateData
---@field win_id number|nil
---@field buf_id number|nil
---@field container Container|nil
---@field container_name string|nil
---@field follow boolean
---@field raw boolean
---@field entries string[]
---@field line_map table|nil

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
end

---@return boolean
function M.is_open()
	if not M.win_id then
		return false
	end

	return vim.api.nvim_win_is_valid(M.win_id)
end

---@return boolean
function M.has_valid_buffer()
	return M.buf_id ~= nil and vim.api.nvim_buf_is_valid(M.buf_id)
end

return M
