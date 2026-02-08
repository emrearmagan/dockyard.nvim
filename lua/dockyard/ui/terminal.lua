local state = require("dockyard.ui.state")

local M = {}

local terminals = {} -- id -> { buf, win }

function M.toggle(item)
	local id = item.id
	local term = terminals[id]

	-- If terminal exists and window is valid, close it (hide)
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_close(term.win, true)
		term.win = nil
		return
	end

	-- If buffer doesn't exist or is invalid, create it
	if not term or not term.buf or not vim.api.nvim_buf_is_valid(term.buf) then
		local buf = vim.api.nvim_create_buf(false, true)
		terminals[id] = { buf = buf, win = nil }
		term = terminals[id]
		
		-- Set name and buffer options
		vim.api.nvim_buf_set_name(buf, "docker-shell-" .. item.name)
		
		-- Open terminal in this buffer
		vim.api.nvim_buf_call(buf, function()
			vim.fn.termopen("docker exec -it " .. id .. " /bin/sh")
		end)
	end

	-- Create floating window
	local editor_w = vim.o.columns
	local editor_h = vim.o.lines
	local width = math.floor(editor_w * 0.8)
	local height = math.floor(editor_h * 0.8)
	local row = math.floor((editor_h - height) / 2)
	local col = math.floor((editor_w - width) / 2)

	local win = vim.api.nvim_open_win(term.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Shell: " .. item.name .. " ",
		title_pos = "center",
	})

	-- Set window options
	vim.api.nvim_win_set_option(win, "winblend", 3)
	
	term.win = win
	vim.cmd("startinsert")
end

return M
