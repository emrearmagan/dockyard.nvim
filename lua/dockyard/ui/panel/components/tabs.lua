local M = {}

---@class DockyardTabDef
---@field key string
---@field label string

---@param tab_defs DockyardTabDef[]
---@param active_tab string
---@param width number
---@param padding_x number|nil
---@return string[] lines
---@return table[] spans
function M.render(tab_defs, active_tab, width, padding_x)
	local pad = math.max(0, padding_x or 0)
	local line = ""
	local spans = {}
	local col = 0

	for i, tab in ipairs(tab_defs or {}) do
		local part = string.format(" %s ", tab.label or "")
		line = line .. part

		local hl = tab.key == active_tab and "DockyardTabActive" or "DockyardTabInactive"
		table.insert(spans, {
			line = 0,
			start_col = col,
			end_col = col + #part,
			hl_group = hl,
		})

		col = col + #part

		if i < #tab_defs then
			line = line .. " "
			col = col + 1
		end
	end

	local padded = string.rep(" ", pad) .. line
	if pad > 0 then
		for _, span in ipairs(spans) do
			span.start_col = span.start_col + pad
			span.end_col = span.end_col + pad
		end
	end

	local divider = string.rep("─", math.max(1, width))
	table.insert(spans, {
		line = 1,
		start_col = 0,
		end_col = #divider,
		hl_group = "DockyardMuted",
	})

	return { padded, divider }, spans
end

return M
