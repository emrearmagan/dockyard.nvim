local M = {}

local BRAILLE_BASE = 0x2800

local LEFT_DOT = { 1, 2, 4, 64 } -- dot offsets for left  column, rows 0-3
local RIGHT_DOT = { 8, 16, 32, 128 } -- dot offsets for right column, rows 0-3

---@class ChartRenderOpts
---@field data number[]
---@field width number
---@field height? number
---@field min? number
---@field max? number
---@field title? string
---@field value? string
---@field hl_group string
---@field title_hl? string
---@field value_hl? string
---@field margin? number

local function format_y_label(v)
	local s
	if v >= 100 then
		s = tostring(math.floor(v))
	elseif v >= 10 then
		s = string.format("%.1f", v)
	elseif v >= 1 then
		s = string.format("%.2f", v)
	else
		s = string.format("%.3f", v)
	end
	if #s > 4 then
		s = s:sub(1, 4)
	end
	return string.format("%4s", s)
end

---@param opts ChartRenderOpts
---@return string[] lines, table[] spans
function M.render(opts)
	local data = opts.data or {}
	local height = opts.height or 6
	local margin = opts.margin or 1
	local hl = opts.hl_group or "Normal"
	local pad = string.rep(" ", margin)
	local width = opts.width or 40

	-- Layout: margin + 4 (y-label) + │ + chart columns
	local sep = "│"
	local chart_cols = math.max(3, width - (margin * 2) - 4 - 1)

	-- Min / max
	local min_val = opts.min
	local max_val = opts.max
	if not min_val or not max_val then
		local lo, hi = math.huge, -math.huge
		for _, v in ipairs(data) do
			if v < lo then
				lo = v
			end
			if v > hi then
				hi = v
			end
		end
		if lo == math.huge then
			lo, hi = 0, 0
		end
		if not min_val then
			min_val = lo
		end
		if not max_val then
			max_val = hi
		end
	end

	if max_val <= min_val then
		local center = min_val
		local epsilon = math.max(math.abs(center) * 0.1, 0.001)
		min_val = center - epsilon
		max_val = center + epsilon
	end

	local range = max_val - min_val

	-- Two data points per terminal column (left and right side of each braille char)
	local data_width = chart_cols * 2
	local sampled = {}
	if #data == 0 then
		for i = 1, data_width do
			sampled[i] = min_val
		end
	elseif #data <= data_width then
		local off = data_width - #data
		for i = 1, off do
			sampled[i] = min_val
		end
		for i = 1, #data do
			sampled[off + i] = data[i]
		end
	else
		local off = #data - data_width
		for i = 1, data_width do
			sampled[i] = data[off + i]
		end
	end

	-- Map each data point to an absolute dot row (0 = top, height*4-1 = bottom)
	local dot_height = height * 4
	local data_dot = {}
	for i = 1, data_width do
		local norm = math.max(0, math.min(1, (sampled[i] - min_val) / range))
		data_dot[i] = math.floor((1 - norm) * (dot_height - 1) + 0.5)
	end

	-- Build the offset grid: grid[col][row] accumulates dot offsets
	local grid = {}
	for c = 1, chart_cols do
		grid[c] = {}
		for r = 0, height - 1 do
			grid[c][r] = 0
		end
	end

	for data_col = 1, data_width do
		local char_col = math.ceil(data_col / 2)
		local dot_offsets = (data_col % 2 == 1) and LEFT_DOT or RIGHT_DOT

		local curr = data_dot[data_col]
		local prev = data_col > 1 and data_dot[data_col - 1] or curr

		for abs_dot = math.min(prev, curr), math.max(prev, curr) do
			local char_row = math.floor(abs_dot / 4)
			local dot_row = abs_dot % 4
			if char_row >= 0 and char_row < height then
				grid[char_col][char_row] = grid[char_col][char_row] + dot_offsets[dot_row + 1]
			end
		end
	end

	local lines = {}
	local spans = {}

	-- Optional title line
	if opts.title or opts.value then
		local title = opts.title or ""
		local value = opts.value or ""
		local content_w = 4 + 1 + chart_cols
		local gap = math.max(2, content_w - vim.fn.strdisplaywidth(title) - vim.fn.strdisplaywidth(value))
		local line = pad .. title .. string.rep(" ", gap) .. value
		table.insert(lines, line)
		if opts.title_hl and title ~= "" then
			table.insert(spans, { line = 0, start_col = margin, end_col = margin + #title, hl_group = opts.title_hl })
		end
		if opts.value_hl and value ~= "" then
			table.insert(spans, { line = 0, start_col = #line - #value, end_col = #line, hl_group = opts.value_hl })
		end
	end

	-- Chart rows
	for char_row = 0, height - 1 do
		local y_label
		if char_row == 0 then
			y_label = format_y_label(max_val)
		elseif char_row == height - 1 then
			y_label = format_y_label(min_val)
		else
			y_label = "    "
		end

		local row_chars = {}
		for c = 1, chart_cols do
			table.insert(row_chars, vim.fn.nr2char(BRAILLE_BASE + grid[c][char_row]))
		end
		local chart_str = table.concat(row_chars)
		local line = pad .. y_label .. sep .. chart_str
		table.insert(lines, line)

		local line_idx = #lines - 1

		if char_row == 0 or char_row == height - 1 then
			table.insert(
				spans,
				{ line = line_idx, start_col = margin, end_col = margin + #y_label, hl_group = "DockyardMuted" }
			)
		end

		local sep_start = margin + #y_label
		table.insert(
			spans,
			{ line = line_idx, start_col = sep_start, end_col = sep_start + #sep, hl_group = "DockyardMuted" }
		)

		local chart_start = sep_start + #sep
		table.insert(
			spans,
			{ line = line_idx, start_col = chart_start, end_col = chart_start + #chart_str, hl_group = hl }
		)
	end

	return lines, spans
end

return M
