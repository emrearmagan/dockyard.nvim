local M = {}

local WIN_WIDTH = 52
local RIGHT_PADDING = 4
local MAX_LINES = 5
local AUTO_CLOSE_MS = 3000

local _current_win = nil
local _current_spinner = nil

local function close_current()
	if _current_spinner ~= nil then
		_current_spinner:stop()
		_current_spinner = nil
	end
	if _current_win ~= nil and vim.api.nvim_win_is_valid(_current_win) then
		pcall(vim.api.nvim_win_close, _current_win, true)
	end
	_current_win = nil
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	once = false,
	callback = close_current,
})

local ns = vim.api.nvim_create_namespace("dockyard.executor")

local function open_notice(title)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	local col = vim.o.columns - WIN_WIDTH - RIGHT_PADDING
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = WIN_WIDTH,
		height = 1,
		row = 1,
		col = col,
		style = "minimal",
		border = "rounded",
		title = title,
		title_pos = "center",
		zindex = 260,
		focusable = true,
	})
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })

	vim.keymap.set("n", "q", function()
		close_current()
	end, { buffer = buf, silent = true, nowait = true })

	return win, buf
end

local function set_lines(buf, win, lines)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	if vim.api.nvim_win_is_valid(win) then
		local h = math.max(1, math.min(#lines, MAX_LINES))
		pcall(vim.api.nvim_win_set_height, win, h)
		pcall(vim.api.nvim_win_set_cursor, win, { #lines, 0 })
	end
end

local function set_title(win, title)
	if vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_set_config, win, { title = title, title_pos = "center" })
	end
end

local function trim(s)
	return s:match("^%s*(.-)%s*$")
end

---@param args string[] Command and arguments
---@param opts { cwd?: string, title?: string }|nil
function M.run(args, opts)
	opts = opts or {}
	if not args or #args == 0 then
		vim.notify("Dockyard: no command to run", vim.log.levels.WARN)
		return
	end

	local cmd = args[1]
	local cmd_args = { unpack(args, 2) }
	local base_title = opts.title or table.concat(args, " ")

	close_current()
	local win, buf = open_notice("  " .. base_title .. " ")
	_current_win = win
	local output_lines = {}

	local spinner = require("dockyard.ui.components.spinner").create({
		on_tick = function(frame)
			set_title(win, " " .. frame .. " " .. base_title .. " ")
		end,
	})
	spinner:start()
	_current_spinner = spinner

	local function append(line)
		line = trim(line)
		if line == "" then
			return
		end
		table.insert(output_lines, " " .. line)
		vim.schedule(function()
			set_lines(buf, win, output_lines)
		end)
	end

	require("plenary.job")
		:new({
			command = cmd,
			args = cmd_args,
			cwd = opts.cwd,
			on_stdout = function(_, data)
				if data then
					append(data)
				end
			end,
			on_stderr = function(_, data)
				if data then
					append(data)
				end
			end,
			on_exit = function(_, return_val)
				vim.defer_fn(function()
					spinner:stop()
					_current_spinner = nil
					vim.schedule(function()
						local ok = return_val == 0
						local icon = ok and "✔" or "✖"
						local status = ok and "Done." or ("Failed (exit " .. tostring(return_val) .. ").")
						table.insert(output_lines, " " .. icon .. " " .. status)
						set_lines(buf, win, output_lines)
						set_title(win, " " .. icon .. " " .. base_title .. " ")
						if vim.api.nvim_buf_is_valid(buf) then
							local hl = ok and "DiagnosticOk" or "DiagnosticError"
							local last = #output_lines - 1
							local line_len = #(vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or "")
							vim.api.nvim_buf_set_extmark(
								buf,
								ns,
								last,
								0,
								{ end_row = last, end_col = line_len, hl_group = hl, hl_eol = true }
							)
						end
						vim.defer_fn(function()
							if _current_win == win then
								close_current()
							end
						end, AUTO_CLOSE_MS)
					end)
				end, AUTO_CLOSE_MS)
			end,
		})
		:start()
end

return M
