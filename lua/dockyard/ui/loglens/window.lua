local M = {}

local LOGLENS_BUFFER_NAME = "dockyard://loglens"

---@param state LogLensState
---@return number buf_id The buffer ID
M.create_buffer = function(state)
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
---@param ui_state UIState
---@return number|nil win_id
M.create_window_fullscreen = function(buf, ui_state)
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

---@param buf number
---@return number|nil win_id
M.create_window_floating = function(buf)
	local total_w = vim.o.columns
	local total_h = vim.o.lines

	local width = math.max(60, math.floor(total_w * 0.7))
	local height = math.max(12, math.floor(total_h * 0.5))
	local row = math.floor((total_h - height) / 2)
	local col = math.floor((total_w - width) / 2)

	local ok, win = pcall(vim.api.nvim_open_win, buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		zindex = 260,
	})
	if not ok or not (win and vim.api.nvim_win_is_valid(win)) then
		vim.notify("LogLens: Failed to create floating window", vim.log.levels.ERROR)
		return nil
	end

	vim.api.nvim_set_option_value("number", false, { win = win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", true, { win = win })

	return win
end

return M
