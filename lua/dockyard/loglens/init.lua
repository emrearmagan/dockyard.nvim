local state = require("dockyard.loglens.state")
local renderer = require("dockyard.loglens.ui.renderer")
local ui_state = require("dockyard.ui.state")
local keymaps = require("dockyard.loglens.keymaps")
local loglens_config = require("dockyard.loglens.config")
local parser_factory = require("dockyard.loglens.parsers")
local stream = require("dockyard.loglens.parsers.stream")
local window = require("dockyard.loglens.ui.window")

local M = {}

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
	if not state.parser_session then
		return
	end
	local rows = state.parser_session:flush()
	if #rows > 0 then
		append_rows(rows)
	end
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
	state.filter = nil
	state.active_source = runtime.source
	state.max_lines = runtime.max_lines
	state.parser_session = session

	renderer.render(state)
	return runtime.tail
end

local function start_container_stream(container, tail)
	local source = state.active_source
	local session = state.parser_session
	if not source or not session then
		return
	end

	stop_stream()
	state.job_id = stream.start(container, source, tail, function(chunk)
		local rows = session:push(chunk)
		if #rows > 0 then
			append_rows(rows)
		end
	end, function()
		flush_parser_session()
	end)
end

---Open LogLens for a container.
---@param container Container|nil
function M.open(container)
	if not container or not container.id then
		vim.notify("LogLens: No valid container selected", vim.log.levels.WARN)
		return
	end

	if not (state.is_open() and state.has_valid_buffer()) then
		local buf = window.create_buffer(state)
		local win = window.create_window_fullscreen(buf, ui_state)
		if not win then
			return
		end
		state.win_id = win

		keymaps.attach(buf, state, {
			close = M.close,
			refresh = function()
				renderer.render(state)
			end,
			open_detail = function()
				local lnum = vim.api.nvim_win_get_cursor(state.win_id)[1]
				local entry = state.line_map and state.line_map[lnum] or nil
				if not entry then
					vim.notify("LogLens: no entry at cursor", vim.log.levels.WARN)
					return
				end
				require("dockyard.loglens.ui.popup").open(entry)
			end,
		})
	end

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

	vim.api.nvim_set_current_win(state.win_id)
end

function M.close()
	flush_parser_session()
	stop_stream()

	if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
		pcall(vim.api.nvim_win_close, state.win_id, true)
	end
	if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
		pcall(vim.api.nvim_buf_delete, state.buf_id, { force = true })
	end
	state.reset()
end

return M
