local state = require("dockyard.loglens.state")
local renderer = require("dockyard.loglens.ui.renderer")
local fake_data = require("dockyard.loglens.fake_data")
local ui_state = require("dockyard.ui.state")
local window = require("dockyard.loglens.ui.window")
local keymaps = require("dockyard.loglens.keymaps")

local M = {}

---Set active container and refresh fake data state.
---@param container Container
local function set_active_container(container)
	state.container = container
	state.container_name = container.name or "unknown"
	state.follow = true
	state.raw = false
	state.entries = fake_data.generate(100)
	state.line_map = nil
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
		keymaps.attach(buf, state, M.close)
	end

	local current_id = state.container and state.container.id or nil
	if current_id ~= container.id then
		set_active_container(container)
		renderer.render(state)
	end

	vim.api.nvim_set_current_win(state.win_id)
end

function M.close()
	if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
		pcall(vim.api.nvim_win_close, state.win_id, true)
	end
	if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
		pcall(vim.api.nvim_buf_delete, state.buf_id, { force = true })
	end

	state.reset()
end

return M
