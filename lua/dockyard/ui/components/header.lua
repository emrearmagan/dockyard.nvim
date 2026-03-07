local M = {}

---@param mode "panel"|"full"
---@param width number
---@return { lines: string[], highlights: table[] }
function M.render(mode, width)
	local label = string.upper(mode or "panel")
	local title = string.format(" Dockyard [%s] ", label)
	local seperator = string.rep("=", math.max(width - 2, 20))

	return {
		lines = { title, seperator },
		highlights = {
			{ line = 0, start_col = 0, end_col = #title, hl_group = "DockyardHeader" },
			{ line = 0, start_col = 1, end_col = 9, hl_group = "DockyardTitle" },
			{ line = 1, start_col = 0, end_col = #seperator, hl_group = "DockyardDim" },
		},
	}
end

return M
