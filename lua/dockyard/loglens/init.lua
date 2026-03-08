local state = require("dockyard.loglens.state")
local renderer = require("dockyard.loglens.ui.renderer")
local fake_data = require("dockyard.loglens.fake_data")
local ui_state = require("dockyard.ui.state")
local keymaps = require("dockyard.loglens.keymaps")

local M = {}
local LOGLENS_BUFFER_NAME = "dockyard://loglens"

---@return number buf_id The buffer ID
local function create_buffer()
	if state.has_valid_buffer() then
		return state.buf_id
	end

	local existing = vim.fn.bufnr(LOGLENS_BUFFER_NAME)
	if existing > 0 and vim.api.nvim_buf_is_valid(existing) then
		state.buf_id = existing
		return existing
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, LOGLENS_BUFFER_NAME)

	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "dockyard-logs", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	state.buf_id = buf

	return buf
end

---Create a bottom split in DockyardFull window and attach buffer.
---@param buf number
---@return number|nil win_id
local function create_window_fullscreen(buf)
	local target_win = ui_state.win_id
	if not (target_win and vim.api.nvim_win_is_valid(target_win)) then
		vim.notify("LogLens: Dockyard window not available", vim.log.levels.ERROR)
		return nil
	end

	local win
	vim.api.nvim_win_call(target_win, function()
		local base_height = vim.api.nvim_win_get_height(target_win)
		local split_height = math.max(8, math.floor(base_height * 0.4))
		vim.cmd(("belowright %dsplit"):format(split_height))
		win = vim.api.nvim_get_current_win()
	end)

	if not (win and vim.api.nvim_win_is_valid(win)) then
		vim.notify("LogLens: Failed to create split window", vim.log.levels.ERROR)
		return nil
	end

	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", true, { win = win })
	vim.api.nvim_set_option_value("winfixheight", true, { win = win })

	return win
end

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
		local buf = create_buffer()
		local win = create_window_fullscreen(buf)
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
