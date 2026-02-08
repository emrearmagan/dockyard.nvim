local state = require("dockyard.ui.state")

local M = {}

local inspect_win = nil
local inspect_buf = nil

function M.open(item)
	if not item or not item.id then return end

	local data, err = require("dockyard.docker").inspect(item.id)
	if err then
		vim.notify("Dockyard: " .. err, vim.log.levels.ERROR)
		return
	end

	-- Create buffer if not exists
	if not inspect_buf or not vim.api.nvim_buf_is_valid(inspect_buf) then
		inspect_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(inspect_buf, "filetype", "json")
		vim.api.nvim_buf_set_option(inspect_buf, "buftype", "nofile")
	end

	local lines = vim.split(vim.json.encode(data), "\n")
	-- Pretty print JSON using built-in tool or simple formatting
	-- Neovim doesn't have a built-in JSON formatter that returns strings easily in 5.1/Lua, 
	-- but we can use jq if available or just raw json.decode/encode with indentation.
	-- Since we want it to look good, let's try to format it.
	
	local formatted = vim.fn.system("jq .", vim.json.encode(data))
	if vim.v.shell_error ~= 0 then
		-- Fallback to simple encode if jq is missing
		lines = vim.split(vim.json.encode(data), "\n")
	else
		lines = vim.split(formatted, "\n")
	end

	vim.api.nvim_buf_set_option(inspect_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(inspect_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(inspect_buf, "modifiable", false)

	-- Calculate size
	local editor_w = vim.o.columns
	local editor_h = vim.o.lines
	local width = math.floor(editor_w * 0.7)
	local height = math.floor(editor_h * 0.7)
	local row = math.floor((editor_h - height) / 2)
	local col = math.floor((editor_w - width) / 2)

	if inspect_win and vim.api.nvim_win_is_valid(inspect_win) then
		vim.api.nvim_win_set_config(inspect_win, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
		})
	else
		inspect_win = vim.api.nvim_open_win(inspect_buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " Inspect: " .. (item.name or item.id) .. " ",
			title_pos = "center",
		})
	end

	-- Keybindings to close
	local opts = { buffer = inspect_buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", function()
		if inspect_win and vim.api.nvim_win_is_valid(inspect_win) then
			vim.api.nvim_win_close(inspect_win, true)
		end
		inspect_win = nil
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		if inspect_win and vim.api.nvim_win_is_valid(inspect_win) then
			vim.api.nvim_win_close(inspect_win, true)
		end
		inspect_win = nil
	end, opts)
end

return M
