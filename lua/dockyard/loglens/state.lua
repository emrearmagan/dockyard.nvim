---@class LogLensEntry
---@field raw string
---@field formatted string
---@field data table<string, any>

---@class LogLensParserSession
---@field push fun(self: LogLensParserSession, chunk: string): LogLensEntry[]
---@field flush fun(self: LogLensParserSession): LogLensEntry[]

---@class LogLensStateData
---@field win_id number|nil
---@field buf_id number|nil
---@field container Container|nil
---@field container_name string|nil
---@field follow boolean
---@field raw boolean
---@field filter string|nil
---@field entries LogLensEntry[]
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
	filter = nil,

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
	M.filter = nil

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
