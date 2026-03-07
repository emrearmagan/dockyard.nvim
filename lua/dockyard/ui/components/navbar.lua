local M = {}

local function to_title_case(value)
	if value == nil or value == "" then
		return ""
	end

	return value:sub(1, 1):upper() .. value:sub(2)
end

---@param current_view string
---@param views string[]
---@return { lines: string[], highlights: table[] }
function M.render(current_view, views)
	local parts = {}
	local spans = {}
	local col = 0

	for i, view in ipairs(views) do
		local label = string.format("[ %s ]", to_title_case(view))
		local hl = view == current_view and "DockyardNavActive" or "DockyardNavInactive"

		table.insert(parts, label)
		table.insert(spans, {
			line = 0,
			start_col = col,
			end_col = col + #label,
			hl_group = hl,
		})

		col = col + #label
		if i < #views then
			table.insert(parts, " ")
			col = col + 1
		end
	end

	local nav_line = table.concat(parts)
	local separator = string.rep("-", math.max(#nav_line, 20))

	table.insert(spans, {
		line = 1,
		start_col = 0,
		end_col = #separator,
		hl_group = "DockyardDim",
	})

	return {
		lines = {
			nav_line,
			separator,
		},
		highlights = spans,
	}
end

return M
