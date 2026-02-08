local containers = require("dockyard.containers")

local M = {}

local namespace = vim.api.nvim_create_namespace("dockyard_ui")

local state = {
	win = nil,
	buf = nil,
	mode = nil,
	_highlight_groups = false,
}

local columns = {
	{ key = "name", min_width = 18, weight = 2 },
	{ key = "image", min_width = 20, weight = 2 },
	{ key = "status", min_width = 14, weight = 1 },
	{ key = "ports", min_width = 20, weight = 2 },
	{ key = "created_since", min_width = 18, weight = 1 },
}

local HEADER_TITLE = "  Docker"

local function text_width(text)
	text = tostring(text or "")
	local ok, width = pcall(vim.fn.strdisplaywidth, text)
	if ok and type(width) == "number" then
		return width
	end
	local ok_alt, fallback = pcall(vim.api.nvim_strwidth, text)
	if ok_alt and type(fallback) == "number" then
		return fallback
	end
	return #text
end

local function str_slice(text, len)
	if len <= 0 then
		return ""
	end
	local ok, slice = pcall(vim.fn.strcharpart, text, 0, len)
	if ok then
		return slice
	end
	return text:sub(1, len)
end

local function truncate(text, width)
	text = tostring(text or "")
	local display = text_width(text)
	if display <= width then
		return text .. string.rep(" ", width - display)
	end
	if width <= 0 then
		return ""
	end
	if width <= 3 then
		return str_slice(text, width)
	end
	return str_slice(text, width - 3) .. "..."
end

local function compute_column_widths(total_width)
	local base = 0
	local total_weight = 0
	for _, col in ipairs(columns) do
		base = base + col.min_width
		total_weight = total_weight + col.weight
	end
	local remaining = math.max(0, total_width - base - ((#columns - 1) * 3))
	local widths = {}
	for idx, col in ipairs(columns) do
		local extra = 0
		if total_weight > 0 then
			extra = math.floor((col.weight / total_weight) * remaining)
		end
		widths[idx] = col.min_width + extra
	end
	return widths
end

local function ensure_buffer()
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		return state.buf
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "dockyard")
	state.buf = buf
	state._mapped = nil
	return buf
end

local function set_lines(bufnr, lines)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end


local MARGIN = 2

local function pad_line(text, width)
	local len = text_width(text)
	if len >= width then
		return text
	end
	return text .. string.rep(" ", width - len)
end

local function center_line(text, width)
	local len = text_width(text)
	if len >= width then
		return text
	end
	local left = math.floor((width - len) / 2)
	local right = width - len - left
	return string.rep(" ", left) .. text .. string.rep(" ", right)
end

local function status_icon(row)
	local status = row.status or ""
	local lower = status:lower()
	if lower:find("up", 1, true) == 1 then
		return "●", "DockyardStatusRunning"
	end
	return "●", "DockyardStatusStopped"
end

local function build_table_lines(rows, width)
	local lines = {}
	local highlights = {}
	local inner_width = math.max(1, width - (MARGIN * 2))
	local column_widths = compute_column_widths(inner_width - 2) -- account for icon + space

	local title = "  " .. HEADER_TITLE .. "  "
	local header_len = text_width(title)
	local header_left = math.floor((width - header_len) / 2)
	lines[#lines + 1] = pad_line(string.rep(" ", header_left) .. title, width)
	highlights[#highlights + 1] = {
		line = #lines - 1,
		col_start = header_left,
		col_end = header_left + #title,
		group = "DockyardHeader",
	}
	lines[#lines + 1] = pad_line("", width)

	-- Column Headers
	local header_cells = {}
	local header_map = {
		name = "Name",
		image = "Image",
		status = "Status",
		ports = "Ports",
		created_since = "Created",
	}
	for idx, col in ipairs(columns) do
		local header_text = header_map[col.key] or col.key
		header_cells[#header_cells + 1] = truncate(header_text, column_widths[idx])
	end
	-- Prefix matches the icon spacing in data rows (MARGIN + icon + space)
	local header_prefix = string.rep(" ", MARGIN + text_width("●") + 1)
	local header_row = header_prefix .. table.concat(header_cells, "   ")
	lines[#lines + 1] = pad_line(header_row, width)
	highlights[#highlights + 1] = {
		line = #lines - 1,
		col_start = 0,
		col_end = -1,
		group = "DockyardColumnHeader",
	}
	lines[#lines + 1] = pad_line("", width)

	local empty_line = string.rep(" ", MARGIN) .. "No running containers"
	if #rows == 0 then
		lines[#lines + 1] = pad_line(empty_line, width)
		return lines, highlights
	end

	for _, row in ipairs(rows) do
		local icon, group = status_icon(row)
		local cells = {}
		local cell_positions = {}
		local current_pos = MARGIN + text_width(icon) + 1

		for idx, col in ipairs(columns) do
			local value = row[col.key]
			if col.key == "ports" then
				value = value ~= "" and value or "-"
			end
			local truncated = truncate(value, column_widths[idx])
			cells[#cells + 1] = truncated
			cell_positions[idx] = { start = current_pos, len = text_width(truncated) }
			current_pos = current_pos + column_widths[idx] + 3 -- 3 for space between columns
		end

		local prefix = string.rep(" ", MARGIN) .. icon .. " "
		local line = prefix .. table.concat(cells, "   ")
		lines[#lines + 1] = pad_line(line, width)

		if group then
			highlights[#highlights + 1] = {
				line = #lines - 1,
				col_start = MARGIN,
				col_end = MARGIN + #icon,
				group = group,
			}
		end

		local column_highlights = {
			name = "DockyardName",
			image = "DockyardImage",
			status = "DockyardMuted",
			ports = "DockyardPorts",
			created_since = "DockyardMuted",
		}

		for idx, col in ipairs(columns) do
			local hl_group = column_highlights[col.key]
			if hl_group then
				highlights[#highlights + 1] = {
					line = #lines - 1,
					col_start = cell_positions[idx].start,
					col_end = cell_positions[idx].start + cell_positions[idx].len,
					group = hl_group,
				}
			end
		end
	end

	return lines, highlights
end

local function build_lines(width)
	local rows = containers.all()
	local lines, highlights = build_table_lines(rows, width)
	return lines, highlights
end

local function attach_keymaps(bufnr)
	if state._mapped then
		return
	end
	state._mapped = true
	local opts = { buffer = bufnr, nowait = true, silent = true }

	-- Smart navigation: jump to next/previous container line
	local function move_to_row(step)
		local curr_line = vim.api.nvim_win_get_cursor(0)[1]
		local total_lines = vim.api.nvim_buf_line_count(0)
		local rows = containers.all()

		-- Determine start line of containers (Header + Spacer + Columns + Spacer = 4 lines)
		local start_data = 5
		if #rows == 0 then
			return
		end

		local next_line = curr_line + step
		if next_line < start_data then
			next_line = start_data
		elseif next_line > start_data + #rows - 1 then
			next_line = start_data + #rows - 1
		end

		vim.api.nvim_win_set_cursor(0, { next_line, MARGIN })
	end

	vim.keymap.set("n", "j", function()
		move_to_row(1)
	end, opts)
	vim.keymap.set("n", "k", function()
		move_to_row(-1)
	end, opts)

	vim.keymap.set("n", "q", function()
		M.close()
	end, opts)
	vim.keymap.set("n", "r", function()
		require("dockyard").refresh({ silent = true })
		M.render(state.mode)
	end, opts)
	vim.keymap.set("n", "?", function()
		vim.notify("Dockyard: j/k move • r refresh • q close", vim.log.levels.INFO)
	end, opts)
end

local function ensure_split_window()
	local buf = ensure_buffer()
	local current_tab = vim.api.nvim_get_current_tabpage()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		if vim.api.nvim_win_get_tabpage(state.win) ~= current_tab then
			state.win = nil
		else
			vim.api.nvim_set_current_win(state.win)
		end
	end

	if not state.win then
		vim.cmd("botright vsplit")
		state.win = vim.api.nvim_get_current_win()
	end

	vim.api.nvim_win_set_buf(state.win, buf)
	vim.api.nvim_win_set_option(state.win, "wrap", false)
	state.mode = "split"
	return state.win
end

local function ensure_tab_window()
	local buf = ensure_buffer()
	if state.win and state.mode == "tab" and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_set_current_win(state.win)
	else
		vim.cmd("tabnew")
		state.win = vim.api.nvim_get_current_win()
	end
	vim.api.nvim_win_set_buf(state.win, buf)
	vim.api.nvim_win_set_option(state.win, "wrap", false)
	state.mode = "tab"
	return state.win
end

local function ensure_highlight_groups()
	if state._highlight_groups then
		return
	end

	if vim.o.background == "dark" then
		vim.api.nvim_set_hl(0, "DockyardHeader", { bg = "#24292f", fg = "#58a6ff", bold = true })
		vim.api.nvim_set_hl(0, "DockyardName", { fg = "#58a6ff" })
		vim.api.nvim_set_hl(0, "DockyardImage", { fg = "#bc8cff" })
		vim.api.nvim_set_hl(0, "DockyardPorts", { fg = "#e3b341" })
		vim.api.nvim_set_hl(0, "DockyardMuted", { fg = "#8b949e" })
	else
		vim.api.nvim_set_hl(0, "DockyardHeader", { bg = "#ebecf0", fg = "#0969da", bold = true })
		vim.api.nvim_set_hl(0, "DockyardName", { fg = "#0969da" })
		vim.api.nvim_set_hl(0, "DockyardImage", { fg = "#8250df" })
		vim.api.nvim_set_hl(0, "DockyardPorts", { fg = "#9a6700" })
		vim.api.nvim_set_hl(0, "DockyardMuted", { fg = "#6e7781" })
	end

	vim.api.nvim_set_hl(0, "DockyardColumnHeader", { fg = "#94a3b8", bold = true })
	vim.api.nvim_set_hl(0, "DockyardStatusRunning", { fg = "#4ade80", bold = true })
	vim.api.nvim_set_hl(0, "DockyardStatusStopped", { fg = "#f87171", bold = true })
	state._highlight_groups = true
end

local function apply_highlights(bufnr, highlights)
	ensure_highlight_groups()
	vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(bufnr, namespace, hl.group, hl.line, hl.col_start, hl.col_end)
	end
end

function M.render(mode)
	mode = mode or "split"
	if mode == "tab" then
		ensure_tab_window()
	else
		ensure_split_window()
	end
	local win = state.win
	local width = vim.api.nvim_win_get_width(win)
	local lines, highlights = build_lines(width)
	local buf = ensure_buffer()
	attach_keymaps(buf)
	set_lines(buf, lines)
	apply_highlights(buf, highlights)

	-- Initially position cursor at the first container
	local rows = containers.all()
	if #rows > 0 then
		local cursor = vim.api.nvim_win_get_cursor(win)
		if cursor[1] < 5 then
			vim.api.nvim_win_set_cursor(win, { 5, MARGIN })
		end
	end

	return win
end

function M.open()
	return M.render("split")
end

function M.open_full()
	return M.render("tab")
end

function M.close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win = nil
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	state.buf = nil
	state._mapped = nil
	state.mode = nil
end

return M
