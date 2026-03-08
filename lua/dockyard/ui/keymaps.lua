local ui = require("dockyard.ui")
local ui_state = require("dockyard.ui.state")

local M = {}

local function cursor_line_1based()
	return vim.api.nvim_win_get_cursor(0)[1]
end

function M.get_item_at_cursor()
	return ui_state.line_map[cursor_line_1based()]
end

function M.attach(buf)
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "q", ui.close, opts)
	vim.keymap.set("n", "R", ui.refresh, opts)
	vim.keymap.set("n", "j", "j", opts)
	vim.keymap.set("n", "k", "k", opts)

	vim.keymap.set("n", "<Tab>", ui.next_view, opts)
	vim.keymap.set("n", "<S-Tab>", ui.prev_view, opts)

	vim.keymap.set("n", "?", function()
		require("dockyard.ui.popups.help").open()
	end, opts)
end

return M
