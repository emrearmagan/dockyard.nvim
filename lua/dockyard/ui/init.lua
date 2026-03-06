local M = {}
local state = require("dockyard.ui.state")

local function panel_win_config()
	local total_w = vim.o.columns
	local total_h = vim.o.lines

	local width = math.floor(total_w * 0.9)
	local height = math.floor(total_h * 0.9)
	local row = math.floor((total_h - height) / 2)
	local col = math.floor((total_w - width) / 2)

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		zindex = 100,
	}
end

local function full_win_config()
	return {
		relative = "editor",
		width = vim.o.columns,
		height = vim.o.lines - 1,
		row = 0,
		col = 0,
		style = "minimal",
		border = "none",
		zindex = 100,
	}
end

local function create_buf()
  vim.api.wrap
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "Dockyard")
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "dockyard")
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	return buf
end

local function apply_win_config(win)
	vim.api.nvim_win_set_option(win, "number", false)
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_option(win, "signcolumn", "no")
	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "cursorline", true)
end

local function open_with(mode, win_config_fn)
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		return
	end

	state.prev_win = vim.api.nvim_get_current_win()
	state.mode = mode

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = create_buf()
	end

	state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_config_fn())
	apply_win_config(state.win_id)

	return state.win_id
end

-- Public API

M.is_open = function()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

M.open = function()
	return open_with("panel", panel_win_config)
end

M.open_full = function()
	return open_with("full", full_win_config)
end

M.close = function()
	if not M.is_open() then
		return
	end

	vim.api.nvim_win_close(state.win_id, true)
	state.win_id = nil

	if state.prev_win ~= nil and vim.api.nvim_win_is_valid(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end

	state.prev_win = nil
end

return M
