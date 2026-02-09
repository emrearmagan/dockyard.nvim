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
	if width <= 0 then return "" end
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
	local remaining = math.max(0, total_width - base - ((#columns - 1) * 2))
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
	local margin = ctx.margin or MARGIN
	local lines = {}
	local highlights = {}

	local icon_width = config.has_icons and 2 or 0 
	local column_widths = M.compute_widths(config.columns, width - (margin * 2) - icon_width)

	-- Column Headers
	local header_cells = {}
	for idx, col in ipairs(config.columns) do
		header_cells[#header_cells + 1] = M.truncate(col.label or col.key, column_widths[idx])
	end
	
	local header_prefix = string.rep(" ", margin + icon_width)
	local header_row = header_prefix .. table.concat(header_cells, "  ")
	lines[#lines + 1] = header_row
	highlights[#highlights + 1] = { line = 0, col_start = 0, col_end = -1, group = "DockyardColumnHeader" }
	lines[#lines + 1] = "" 

	-- Data Rows
	if #rows == 0 then
		lines[#lines + 1] = string.rep(" ", margin) .. (config.empty_message or "No data")
	else
		for _, row in ipairs(rows) do
			if row._is_spacer then
				lines[#lines + 1] = ""
			else
				local cells = {}
				local cell_positions = {}
				local row_prefix = string.rep(" ", margin)
				local current_byte_pos = margin

				-- 1. Margin Icon
				if config.has_icons and config.get_row_icon and not row._custom_icon_logic then
					local icon, icon_hl = config.get_row_icon(row)
					row_prefix = row_prefix .. icon .. " "
					highlights[#highlights + 1] = {
						line = #lines,
						col_start = margin,
						col_end = margin + #icon,
						group = icon_hl or "Normal",
					}
					current_byte_pos = current_byte_pos + #icon + 1
				elseif row._custom_icon_logic then
					row_prefix = row_prefix .. string.rep(" ", icon_width)
					current_byte_pos = current_byte_pos + icon_width
				end
				
				-- 2. Columns
				local row_indent_str = row._indent or ""
				local indent_w = M.text_width(row_indent_str)

				for idx, col in ipairs(config.columns) do
					local value = tostring(row[col.key] or "-")
					local col_w = column_widths[idx]
					local truncated = ""
					
					if idx == 1 then
						-- First column includes the indentation visually
						local content_w = math.max(0, col_w - indent_w)
						truncated = row_indent_str .. M.truncate(value, content_w)
					else
						truncated = M.truncate(value, col_w)
					end
					
					cells[#cells + 1] = truncated
					cell_positions[idx] = { 
						start = current_byte_pos, 
						len = #truncated, 
						hl = col.hl,
						indent_len = (idx == 1) and #row_indent_str or 0
					}
					current_byte_pos = current_byte_pos + #truncated + 2
				end

				lines[#lines + 1] = row_prefix .. table.concat(cells, "  ")

				-- 3. Cell Highlights
				for i, pos in ipairs(cell_positions) do
					if pos.hl then
						local hl_start = pos.start + pos.indent_len
						-- Offset for custom status icons inside the text
						if i == 1 and row._name_icon_hl then
							hl_start = hl_start + row._name_icon_hl.len + 1
						end

						highlights[#highlights + 1] = {
							line = #lines - 1,
							col_start = hl_start,
							col_end = pos.start + pos.len,
							group = pos.hl,
						}
					end
					
					-- Nested status icon highlighting
					if i == 1 and row._name_icon_hl then
						local icon_start = pos.start + pos.indent_len
						highlights[#highlights + 1] = {
							line = #lines - 1,
							col_start = icon_start,
							col_end = icon_start + row._name_icon_hl.len,
							group = row._name_icon_hl.group,
						}
					end
				end
			end
		end
	end

	return lines, highlights
end

return M
