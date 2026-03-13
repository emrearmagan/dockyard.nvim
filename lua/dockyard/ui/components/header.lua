local M = {}

local function center_text(text, width)
	local content_width = vim.fn.strdisplaywidth(text)
	if content_width >= width then
		return text, 0
	end

	local left_pad = math.floor((width - content_width) / 2)
	return string.rep(" ", left_pad) .. text, left_pad
end

---@param mode "panel"|"full"
---@param width number
---@return { lines: string[], highlights: table[] }
function M.render(mode, width)
	local inner = math.max(width - 2, 20)
	local title = "    Dockyard  "
	local line, start_col = center_text(title, inner)

	return {
		lines = {
			line,
			"",
		},
		highlights = {
			{ line = 0, start_col = start_col, end_col = start_col + #title, hl_group = "DockyardHeader" },
		},
	}
end

return M
