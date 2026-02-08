local state = require("dockyard.ui.state")
local renderer = require("dockyard.ui.renderer")

local M = {}

function M.render(mode)
	state.mode = mode or state.mode or "split"
	renderer.ensure_hl_groups()

	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(state.buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(state.buf, "filetype", "dockyard")
	end

	if state.mode == "tab" then
		if not state.win or not vim.api.nvim_win_is_valid(state.win) then
			vim.cmd("tabnew")
			state.win = vim.api.nvim_get_current_win()
		end
	else
		if not state.win or not vim.api.nvim_win_is_valid(state.win) then
			vim.cmd("botright vsplit")
			state.win = vim.api.nvim_get_current_win()
		end
	end

	vim.api.nvim_win_set_buf(state.win, state.buf)
	vim.api.nvim_win_set_option(state.win, "wrap", false)
	vim.api.nvim_win_set_option(state.win, "number", false)
	vim.api.nvim_win_set_option(state.win, "relativenumber", false)
	vim.api.nvim_win_set_option(state.win, "signcolumn", "no")
	vim.api.nvim_win_set_option(state.win, "foldcolumn", "0")
	vim.api.nvim_win_set_option(state.win, "winfixwidth", true)
	vim.api.nvim_win_set_option(state.win, "cursorline", true)
	vim.api.nvim_win_set_option(state.win, "winhighlight", "CursorLine:DockyardCursorLine")

	local table_start, comp = renderer.draw()
	require("dockyard.ui.keymaps").setup(table_start, comp)

	return state.win
end

function M.open() return M.render("split") end
function M.open_full() return M.render("tab") end

function M.close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win = nil
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	state.buf = nil
end

return M
