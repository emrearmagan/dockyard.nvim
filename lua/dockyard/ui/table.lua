local M = {}

local MARGIN = 2

function M.text_width(text)
	text = tostring(text or "")
	local ok, width = pcall(vim.fn.strdisplaywidth, text)
	return (ok and type(width) == "number") and width or #text
end

function M.truncate(text, width)
	text = tostring(text or "")
	local display = M.text_width(text)
	if display <= width then
		return text .. string.rep(" ", width - display)
	end
	if width <= 3 then
		local ok, slice = pcall(vim.fn.strcharpart, text, 0, width)
		return ok and slice or text:sub(1, width)
	end
	local ok, slice = pcall(vim.fn.strcharpart, text, 0, width - 3)
	return (ok and slice or text:sub(1, width - 3)) .. "..."
end

function M.compute_widths(columns, total_width)
	local base = 0
	local total_weight = 0
	for _, col in ipairs(columns) do
		base = base + col.min_width
		total_weight = total_weight + col.weight
	end
	local remaining = math.max(0, total_width - base - ((#columns - 1) * 3))
	local widths = {}
	for idx, col in ipairs(columns) do
		local extra = total_weight > 0 and math.floor((col.weight / total_weight) * remaining) or 0
		widths[idx] = col.min_width + extra
	end
	return widths
end

function M.render(ctx)
	local config = ctx.config
	local rows = ctx.rows
	local width = ctx.width
	local lines = {}
	local highlights = {}

	local icon_width = config.has_icons and 2 or 0 -- icon + space
	local column_widths = M.compute_widths(config.columns, width - (MARGIN * 2) - icon_width)

	-- Column Headers
	local header_cells = {}
	for idx, col in ipairs(config.columns) do
		header_cells[#header_cells + 1] = M.truncate(col.label or col.key, column_widths[idx])
	end
	local header_row = string.rep(" ", MARGIN + icon_width) .. table.concat(header_cells, "   ")
	lines[#lines + 1] = header_row
	highlights[#highlights + 1] = { line = 0, col_start = 0, col_end = -1, group = "DockyardColumnHeader" }
	lines[#lines + 1] = "" -- Spacer after headers

	-- Data Rows
	if #rows == 0 then
		lines[#lines + 1] = string.rep(" ", MARGIN) .. (config.empty_message or "No data")
	else
		for _, row in ipairs(rows) do
			local cells = {}
			local cell_positions = {}
			local current_pos = MARGIN + icon_width

			for idx, col in ipairs(config.columns) do
				local value = tostring(row[col.key] or "-")
				local truncated = M.truncate(value, column_widths[idx])
				cells[#cells + 1] = truncated
				cell_positions[idx] = { start = current_pos, len = M.text_width(truncated), hl = col.hl }
				current_pos = current_pos + column_widths[idx] + 3
			end

			local row_prefix = string.rep(" ", MARGIN)
			if config.has_icons and config.get_row_icon then
				local icon, icon_hl = config.get_row_icon(row)
				row_prefix = row_prefix .. icon .. " "
				highlights[#highlights + 1] = {
					line = #lines,
					col_start = MARGIN,
					col_end = MARGIN + #icon,
					group = icon_hl or "Normal",
				}
			end

			lines[#lines + 1] = row_prefix .. table.concat(cells, "   ")
			for _, pos in ipairs(cell_positions) do
				if pos.hl then
					highlights[#highlights + 1] = {
						line = #lines - 1,
						col_start = pos.start,
						col_end = pos.start + pos.len,
						group = pos.hl,
					}
				end
			end
		end
	end

	return lines, highlights
end

return M
