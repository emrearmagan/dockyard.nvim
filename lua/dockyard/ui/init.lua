local M = {}
local state = require("dockyard.ui.state")
local data_state = require("dockyard.state")
local renderer = require("dockyard.ui.renderer")

local win_config_by_mode = {}

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

win_config_by_mode.panel = panel_win_config
win_config_by_mode.full = full_win_config

local function create_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "Dockyard")
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("filetype", "dockyard", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	return buf
end

local function apply_win_config(win, mode)
	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", true, { win = win })

	if mode == "full" then
		vim.api.nvim_set_option_value(
			"winhighlight",
			"Normal:Normal,NormalFloat:Normal,FloatBorder:FloatBorder,CursorLine:CursorLine",
			{ win = win }
		)
	else
		vim.api.nvim_set_option_value(
			"winhighlight",
			"Normal:NormalFloat,NormalFloat:NormalFloat,FloatBorder:FloatBorder,CursorLine:CursorLine",
			{ win = win }
		)
	end
end

local function open_with(mode, win_config_fn)
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		renderer.render()
		return state.win_id
	end

	state.prev_win = vim.api.nvim_get_current_win()
	state.mode = mode

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = create_buf()
	end

	state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_config_fn())
	apply_win_config(state.win_id, mode)
	renderer.render()

	data_state.containers.refresh({
		silent = true,
		on_success = function()
			if M.is_open() then
				renderer.render()
			end
		end,
		on_error = function()
			if M.is_open() then
				renderer.render()
			end
		end,
	})

	return state.win_id
end

M.resize = function()
	if not M.is_open() then
		return
	end

	local config_fn = win_config_by_mode[state.mode] or panel_win_config
	vim.api.nvim_win_set_config(state.win_id, config_fn())
	renderer.render()
end

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

M.refresh = function()
	if M.is_open() then
		renderer.render()
	end
end

local resize_group = vim.api.nvim_create_augroup("DockyardUIResize", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
	group = resize_group,
	callback = function()
		M.resize()
	end,
})

return M
