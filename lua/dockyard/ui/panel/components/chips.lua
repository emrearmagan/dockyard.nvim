local M = {}

---@class DockyardChipItem
---@field text string
---@field hl_group string

---@param items DockyardChipItem[]
---@param width number
---@param padding_x number|nil
---@return string line
---@return table[] spans
function M.render(items, width, padding_x)
	local rendered = {}
	for _, item in ipairs(items or {}) do
		if type(item.text) == "string" and item.text ~= "" then
			table.insert(rendered, {
				text = " " .. item.text .. " ",
				hl_group = item.hl_group,
			})
		end
	end

	if #rendered == 0 then
		return "", {}
	end

	local gap = " "
	local parts = {}
	for i, chip in ipairs(rendered) do
		table.insert(parts, chip.text)
		if i < #rendered then
			table.insert(parts, gap)
		end
	end

	local content = table.concat(parts)
	local pad = math.max(0, padding_x or 0)
	local line = string.rep(" ", pad) .. content

	local spans = {}
	local cursor = pad
	for i, chip in ipairs(rendered) do
		table.insert(spans, {
			line = 0,
			start_col = cursor,
			end_col = cursor + #chip.text,
			hl_group = chip.hl_group,
		})
		cursor = cursor + #chip.text
		if i < #rendered then
			cursor = cursor + #gap
		end
	end

	return line, spans
end

return M
