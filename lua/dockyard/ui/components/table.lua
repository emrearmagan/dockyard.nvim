local M = {}

local function display_width(text)
	return vim.fn.strdisplaywidth(text or "")
end

local function pad_right(text, width)
	local w = display_width(text)
	if w >= width then
		return text
	end
	return text .. string.rep(" ", width - w)
end

local function truncate(text, width)
	text = tostring(text or "")

	if width <= 1 then
		return text:sub(1, width)
	end

	if display_width(text) <= width then
		return text
	end

	local out = ""
	for ch in text:gmatch(".") do
		if display_width(out .. ch .. "…") > width then
			break
		end
		out = out .. ch
	end

	return out .. "…"
end

local function resolve_tree(opts)
	if type(opts) ~= "table" then
		return nil
	end

	return {
		children_key = opts.children_key or "children",
		expanded_field = opts.expanded_field or "expanded",
		default_expanded = opts.default_expanded == true,
		indent = opts.indent or "  ",
		leaf_prefix = opts.leaf_prefix or "└─ ",
		show_indicator = opts.show_indicator ~= false,
		is_expanded = opts.is_expanded,
	}
end

local function row_is_expanded(row, has_children, tree)
	if not has_children then
		return false
	end
	if type(tree.is_expanded) == "function" then
		return tree.is_expanded(row) == true
	end
	if row[tree.expanded_field] ~= nil then
		return row[tree.expanded_field] == true
	end
	return tree.default_expanded
end

local function flatten_rows(rows, tree)
	if tree == nil then
		return rows
	end

	local out = {}

	local function walk(list, depth)
		for _, row in ipairs(list or {}) do
			local children = row[tree.children_key]
			local has_children = type(children) == "table" and #children > 0
			local expanded = row_is_expanded(row, has_children, tree)
			local row_view = vim.tbl_extend("force", row, {
				_tree_level = depth,
				_tree_has_children = has_children,
				_tree_expanded = expanded,
			})
			table.insert(out, row_view)

			if has_children and expanded then
				walk(children, depth + 1)
			end
		end
	end

	walk(rows, 0)
	return out
end

local function tree_prefix(row, col_index, tree)
	if tree == nil or col_index ~= 1 then
		return ""
	end

	local level = row._tree_level or 0
	local indent = string.rep(tree.indent, level)
	if not tree.show_indicator then
		return indent
	end

	if row._tree_has_children then
		return indent .. (row._tree_expanded and "▾ " or "▸ ")
	end

	if level == 0 then
		if not tree.show_indicator then
			return ""
		end
		return "  "
	end

	return indent .. tree.leaf_prefix
end

local function cell_text(row, column, col_index, tree)
	return tree_prefix(row, col_index, tree) .. tostring(row[column.key] or "")
end

local function natural_width(column, rows, col_index, tree)
	if column.width then
		return column.width
	end

	local w = display_width(column.name or column.key or "")
	for _, row in ipairs(rows) do
		w = math.max(w, display_width(cell_text(row, column, col_index, tree)))
	end

	return w
end

---Compute final per-column widths for current window width.
---
---Rules:
---1) Start from natural width (longest header/cell content).
---2) If row is wider than available space, repeatedly shrink the
---   currently widest non-fixed column by one cell.
---3) If there is extra room, repeatedly grow the currently smallest
---   growable column by one cell.
---
---Growth constraints:
--- - Fixed columns (`width`) never grow.
--- - If `max_width` is set, that column will not grow beyond it.
--- - Last column does not grow beyond natural content width unless
---   `grow_last = true` is set on that column.
---
---Why widest-first?
---It preserves readability by trimming oversized columns before
---squeezing already narrow columns.
---
---@param columns table[]
---@param rows table[]
---@param available_width number content area width (excluding left margin)
---@param gap_after fun(index:number):number
local function compute_widths(columns, rows, available_width, gap_after, tree)
	local widths = {}
	for i, c in ipairs(columns) do
		widths[i] = natural_width(c, rows, i, tree)
	end
	local desired = vim.deepcopy(widths)

	local function total_used()
		local sum = 0
		for _, w in ipairs(widths) do
			sum = sum + w
		end
		for i = 1, math.max(#columns - 1, 0) do
			sum = sum + gap_after(i)
		end
		return sum
	end

	while total_used() > available_width do
		local widest_idx = nil
		local widest_width = -1

		for i, col in ipairs(columns) do
			if not col.width and widths[i] > widest_width and widths[i] > 1 then
				widest_idx = i
				widest_width = widths[i]
			end
		end

		if widest_idx == nil then
			break
		end

		widths[widest_idx] = widths[widest_idx] - 1
	end

	-- Fill remaining room by growing the smallest eligible column each step.
	while total_used() < available_width do
		local smallest_idx = nil
		local smallest_width = math.huge

		for i, col in ipairs(columns) do
			if not col.width then
				local is_last = (i == #columns)
				local allow_grow_last = col.grow_last == true
				local capped_by_last = is_last and (not allow_grow_last) and widths[i] >= desired[i]
				local capped_by_max = col.max_width ~= nil and widths[i] >= col.max_width

				if not capped_by_last and not capped_by_max then
					if widths[i] < smallest_width then
						smallest_idx = i
						smallest_width = widths[i]
					end
				end
			end
		end

		if smallest_idx == nil then
			break
		end

		widths[smallest_idx] = widths[smallest_idx] + 1
	end

	for i, c in ipairs(columns) do
		c._computed = widths[i]
	end
end

function M.render(opts)
	local columns = vim.deepcopy(opts.columns or {})
	local tree = resolve_tree(opts.tree)
	local rows = flatten_rows(opts.rows or {}, tree)
	local width = opts.width or vim.o.columns
	local margin = opts.margin or 2
	local right_margin = opts.right_margin or margin
	local cell_hl = opts.cell_hl
	local default_gap = opts.column_gap or 2

	local function gap_after(index)
		local c = columns[index]
		if not c then
			return default_gap
		end
		if c.gap_after ~= nil then
			return c.gap_after
		end
		return default_gap
	end

	local function join_parts(parts)
		if #parts == 0 then
			return ""
		end

		local out = parts[1]
		for i = 2, #parts do
			out = out .. string.rep(" ", gap_after(i - 1)) .. parts[i]
		end
		return out
	end

	-- Keep both left and right padding so table aligns with navbar framing.
	compute_widths(columns, rows, math.max(width - margin - right_margin, 1), gap_after, tree)

	local lines = {}
	local line_map = {}
	local spans = {}

	-- header
	local header_parts = {}
	local col_start = margin
	for i, c in ipairs(columns) do
		local label = truncate(c.name or "", c._computed)
		local padded = pad_right(label, c._computed)
		table.insert(header_parts, padded)

		table.insert(spans, {
			line = 0,
			start_col = col_start,
			end_col = col_start + #padded,
			hl_group = c.header_hl or "DockyardColumnHeader",
		})

		col_start = col_start + #padded + gap_after(i)
	end
	table.insert(lines, string.rep(" ", margin) .. join_parts(header_parts))
	table.insert(lines, "")

	-- body
	for _, row in ipairs(rows) do
		local line_parts = {}
		col_start = margin
		for i, c in ipairs(columns) do
			local cell = truncate(cell_text(row, c, i, tree), c._computed)
			local padded = pad_right(cell, c._computed)
			table.insert(line_parts, padded)

			local hl = nil
			if type(cell_hl) == "function" then
				hl = cell_hl(row, c)
			end
			hl = hl or c.hl
			if hl then
				table.insert(spans, {
					line = #lines,
					start_col = col_start,
					end_col = col_start + #padded,
					hl_group = hl,
				})
			end

			col_start = col_start + #padded + gap_after(i)
		end
		table.insert(lines, string.rep(" ", margin) .. join_parts(line_parts))
		line_map[#lines] = row._item or row
	end

	return lines, line_map, spans
end

return M
