local colors = require("dockyard.ui.colors")
local state = require("dockyard.ui.state")

local M = {}

local help_win = nil
local help_buf = nil

local function get_keymaps()
	return {
		{
			section = "Navigation",
			maps = {
				{ key = "j / k", desc = "Move cursor down / up" },
				{ key = "Tab / S-Tab", desc = "Next / Previous Tab" },
			},
		},
		{
			section = "Container Actions",
			maps = {
				{ key = "s", desc = "Toggle Start / Stop" },
				{ key = "r", desc = "Restart container" },
				{ key = "d", desc = "Remove container" },
				{ key = "L", desc = "View logs (follow)" },
				{ key = "K / CR", desc = "Show details (Inspect)" },
				{ key = "S", desc = "Open shell (/bin/sh)" },
			},
		},
		{
			section = "Image Actions",
			maps = {
				{ key = "d", desc = "Remove image" },
				{ key = "P", desc = "Prune dangling images" },
				{ key = "K / CR", desc = "Show details (Inspect)" },
				{ key = "o", desc = "Toggle collapse / expand" },
			},
		},
		{
			section = "Network Actions",
			maps = {
				{ key = "d", desc = "Remove network" },
				{ key = "K / CR", desc = "Show details (Inspect)" },
				{ key = "o", desc = "Toggle collapse / expand" },
			},
		},
		{
			section = "General",
			maps = {
				{ key = "R", desc = "Refresh current view" },
				{ key = "q", desc = "Close Dockyard" },
				{ key = "?", desc = "Toggle this help menu" },
			},
		},
	}
end

function M.toggle()
	if help_win and vim.api.nvim_win_is_valid(help_win) then
		vim.api.nvim_win_close(help_win, true)
		help_win = nil
		return
	end

	local sections = get_keymaps()
	local lines = { " Keyboard Shortcuts ", "" }
	local highlights = {}

	-- Add Header Highlight
	table.insert(highlights, { line = 0, col_start = 0, col_end = -1, group = "DockyardHeader" })

	for _, section in ipairs(sections) do
		table.insert(lines, "  " .. section.section)
		table.insert(highlights, { line = #lines - 1, col_start = 2, col_end = -1, group = "DockyardColumnHeader" })
		table.insert(lines, "")

		for _, map in ipairs(section.maps) do
			local key_str = string.format("    %-10s", map.key)
			local line = key_str .. " " .. map.desc
			table.insert(lines, line)
			table.insert(
				highlights,
				{ line = #lines - 1, col_start = 4, col_end = 4 + #map.key, group = "DockyardHelpKey" }
			)
			table.insert(highlights, { line = #lines - 1, col_start = 15, col_end = -1, group = "DockyardHelpDesc" })
		end
		table.insert(lines, "")
	end

	-- Create Buffer
	help_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
	vim.api.nvim_buf_set_option(help_buf, "buftype", "nofile")

	-- Calculate size
	local max_w = 0
	for _, l in ipairs(lines) do
		max_w = math.max(max_w, #l)
	end
	local width = max_w + 4
	local height = #lines

	-- Center in the main editor
	local editor_w = vim.o.columns
	local editor_h = vim.o.lines
	local row = math.floor((editor_h - height) / 2)
	local col = math.floor((editor_w - width) / 2)

	help_win = vim.api.nvim_open_win(help_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Help ",
		title_pos = "center",
	})

	-- Apply Highlights
	local ns = vim.api.nvim_create_namespace("dockyard_help")
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(help_buf, ns, hl.group, hl.line, hl.col_start, hl.col_end)
	end

	-- Close on any key except '?' which toggles
	local opts = { buffer = help_buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", M.toggle, opts)
	vim.keymap.set("n", "<Esc>", M.toggle, opts)
	vim.keymap.set("n", "?", M.toggle, opts)
end

return M
