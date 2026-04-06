local state = require("dockyard.loglens.state")
local renderer = require("dockyard.loglens.ui.renderer")
local ui_state = require("dockyard.ui.state")
local keymaps = require("dockyard.loglens.keymaps")
local window = require("dockyard.loglens.ui.window")
local log_core = require("dockyard.loglens.core")

local M = {}

local stream_instance = nil

local function ensure_stream()
	if stream_instance then
		return stream_instance
	end

	stream_instance = log_core.create({
		on_entries = function(entries)
			state.entries = entries
			renderer.render(state)
		end,
	})

	return stream_instance
end

local function sync_state_from_instance(inst)
	state.container = inst.container
	state.container_name = inst.container_name
	state.entries = inst.entries
	state.active_source = inst.active_source
	state.max_lines = inst.max_lines
	state.parser_sessions = inst._parser_sessions
	state.job_ids = inst._job_ids
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
		local win
		if ui_state.mode == "panel" then
			win = window.create_window_floating(buf)
		else
			win = window.create_window_fullscreen(buf, ui_state)
		end
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

	local inst = ensure_stream()
	local current_id = inst.container and inst.container.id or nil
	if current_id ~= container.id then
		state.line_map = nil
		state.filter = nil

		local ok, err = inst:start(container)
		if not ok then
			vim.notify("LogLens: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		sync_state_from_instance(inst)
		renderer.render(state)
	end

	vim.api.nvim_set_current_win(state.win_id)
end

function M.close()
	if stream_instance then
		stream_instance:stop()
		stream_instance = nil
	end

	if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
		pcall(vim.api.nvim_win_close, state.win_id, true)
	end
	if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
		pcall(vim.api.nvim_buf_delete, state.buf_id, { force = true })
	end
	state.reset()
end

return M
