local M = {}

local icons = require("dockyard.ui.icons")
local highlights = require("dockyard.ui.highlights")

---TODO: Add types
---@param node table|nil
---@param width number
---@return string[] lines, table[] spans
function M.render(node, width)
	if not node or not node.item then
		return { "", "  Nothing selected..." }, {}
	end

	local kind = node.kind or "unknown"
	local item = node.item
	local lines = {}
	local spans = {}

	local type_line = ""
	local title_line = ""

	if kind == "container" then
		local icon = icons.container_icon(item.status)
		local status = (item.status or "unknown"):upper()
		type_line = string.format(" %s Container  %s", icon, status)
		title_line = " " .. (item.name or item.id or "-")

		table.insert(spans, {
			line = 0,
			start_col = 1,
			end_col = 1 + #icon,
			hl_group = highlights.status_hl(item.status),
		})
	elseif kind == "image" then
		local icon = icons.image_icon("default")
		type_line = string.format(" %s Image", icon)
		title_line = " " .. (item.repository or "<none>") .. ":" .. (item.tag or "<none>")

		table.insert(spans, {
			line = 0,
			start_col = 1,
			end_col = 1 + #icon,
			hl_group = "DockyardImage",
		})
	elseif kind == "network" then
		local icon = icons.network_icon("default")
		type_line = string.format(" %s Network", icon)
		title_line = " " .. (item.name or "-")

		table.insert(spans, {
			line = 0,
			start_col = 1,
			end_col = 1 + #icon,
			hl_group = "DockyardImage",
		})
	elseif kind == "volume" then
		local icon = icons.volume_icon("default")
		type_line = string.format(" %s Volume", icon)
		title_line = " " .. (item.name or "-")

		table.insert(spans, {
			line = 0,
			start_col = 1,
			end_col = 1 + #icon,
			hl_group = "DockyardImage",
		})
	else
		type_line = " Unknown"
		title_line = " -"
	end

	table.insert(lines, type_line)
	table.insert(lines, title_line)
	table.insert(lines, "")

	-- Header background
	table.insert(spans, { line = 0, start_col = 0, end_col = math.max(#type_line, width), hl_group = "DockyardHeader" })
	table.insert(
		spans,
		{ line = 1, start_col = 0, end_col = math.max(#title_line, width), hl_group = "DockyardHeader" }
	)
	table.insert(spans, { line = 1, start_col = 1, end_col = #title_line, hl_group = "DockyardName" })

	return lines, spans
end

return M
