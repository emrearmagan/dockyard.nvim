local M = {}

local help_buf = nil
local help_win = nil
local ns = vim.api.nvim_create_namespace("dockyard.help")
local resize_group = vim.api.nvim_create_augroup("DockyardHelpPopupResize", { clear = true })

local sections = {
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
			{ key = "L", desc = "Open inspect popup" },
		},
	},
	{
		section = "General",
		maps = {
			{ key = "R", desc = "Refresh current view" },
			{ key = "q", desc = "Close Dockyard" },
			{ key = "?", desc = "Toggle this help popup" },
		},
	},
}

local function render_content()
	local lines = { " Keyboard Shortcuts ", "" }
	local spans = {}

	-- Header
	table.insert(spans, {
		line = 0,
		start_col = 0,
		end_col = -1,
		hl_group = "DockyardHeader",
	})

	for _, section in ipairs(sections) do
		table.insert(lines, " " .. section.section)
		table.insert(spans, {
			line = #lines - 1,
			start_col = 2,
			end_col = -1,
			hl_group = "DockyardColumnHeader",
		})

		for _, map in ipairs(section.maps) do
			local key_col = string.format("    %-12s", map.key)
			local line = key_col .. map.desc
			table.insert(lines, line)

			table.insert(spans, {
				line = #lines - 1,
				start_col = 4,
				end_col = 4 + #map.key,
				hl_group = "DockyardHelpKey",
			})

			table.insert(spans, {
				line = #lines - 1,
				start_col = #key_col + 1,
				end_col = -1,
				hl_group = "DockyardMuted",
			})
		end
		table.insert(lines, "")
	end

	return lines, spans
end

local function window_spec(lines)
	local max_w = 0
	for _, l in ipairs(lines) do
		max_w = math.max(max_w, vim.fn.strdisplaywidth(l))
	end
	local width = max_w + 4
	local height = #lines
	local editor_w = vim.o.columns
	local editor_h = vim.o.lines
	local col = math.floor((editor_w - width) / 2)
	local row = math.floor((editor_h - height) / 2)

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Help ",
		title_pos = "center",
		zindex = 260,
	}
end

local function apply_window_style(win)
	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:NormalFloat,NormalNC:NormalFloat,EndOfBuffer:NormalFloat,FloatBorder:FloatBorder",
		{ win = win }
	)
	vim.api.nvim_set_option_value("wrap", false, { win = win })
	vim.api.nvim_set_option_value("cursorline", false, { win = win })
end

local function ensure_buffer()
	if help_buf ~= nil and vim.api.nvim_buf_is_valid(help_buf) then
		return help_buf
	end

	help_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = help_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = help_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = help_buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = help_buf })

	-- If buffer is wiped, clear module references.
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = help_buf,
		once = true,
		callback = function()
			help_buf = nil
			help_win = nil
		end,
	})

	return help_buf
end

local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, span in ipairs(spans or {}) do
		local line_text = vim.api.nvim_buf_get_lines(buf, span.line, span.line + 1, false)[1] or ""
		local line_len = #line_text

		local start_col = math.max(0, math.min(span.start_col or 0, line_len))
		local end_col = span.end_col
		if end_col == nil or end_col < 0 then
			end_col = line_len
		else
			end_col = math.max(start_col, math.min(end_col, line_len))
		end

		if end_col > start_col and span.hl_group then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, start_col, {
				end_row = span.line,
				end_col = end_col,
				hl_group = span.hl_group,
			})
		end
	end
end

local function close()
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		vim.api.nvim_win_close(help_win, true)
	end
	help_win = nil
end

local function recenter_if_open()
	if help_win == nil or not vim.api.nvim_win_is_valid(help_win) then
		return
	end
	if help_buf == nil or not vim.api.nvim_buf_is_valid(help_buf) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(help_buf, 0, -1, false)
	vim.api.nvim_win_set_config(help_win, window_spec(lines))
end

function M.open()
	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		close()
		return
	end

	local lines, spans = render_content()
	local buf = ensure_buffer()
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	apply_spans(buf, spans)

	if help_win ~= nil and vim.api.nvim_win_is_valid(help_win) then
		vim.api.nvim_win_set_config(help_win, window_spec(lines))
		vim.api.nvim_set_current_win(help_win)
	else
		help_win = vim.api.nvim_open_win(buf, true, window_spec(lines))
	end
	apply_window_style(help_win)

	local opts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)
	vim.keymap.set("n", "?", close, opts)
end

vim.api.nvim_create_autocmd("VimResized", {
	group = resize_group,
	callback = recenter_if_open,
})

return M
