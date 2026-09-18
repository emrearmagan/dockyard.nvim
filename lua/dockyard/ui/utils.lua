local M = {}
local ns = vim.api.nvim_create_namespace("dockyard.ui")

function M.append_block(lines, spans, block)
	local base = #lines

	for _, line in ipairs(block.lines or {}) do
		table.insert(lines, line)
	end

	for _, span in ipairs(block.highlights or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.append_body(lines, spans, body_lines, body_spans)
	local body_start = #lines

	for _, line in ipairs(body_lines or {}) do
		table.insert(lines, line)
	end

	for _, span in ipairs(body_spans or {}) do
		table.insert(spans, {
			line = body_start + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return body_start
end

function M.apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, span in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.panel_win_config()
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

function M.full_win_config()
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

M.win_config_by_mode = {
	panel = M.panel_win_config,
	full = M.full_win_config,
}

function M.create_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "Dockyard")
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
	vim.api.nvim_set_option_value("filetype", "dockyard", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	return buf
end

function M.apply_win_config(win, mode)
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

return M
