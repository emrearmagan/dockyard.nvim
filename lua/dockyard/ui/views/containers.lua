local M = {}

local docker = require("dockyard.docker")
local state = require("dockyard.state")
local table_view = require("dockyard.ui.components.table")
local highlights = require("dockyard.ui.highlights")

local function status_icon(status)
	if status == "running" then
		return "●"
	end
	if status == "paused" then
		return "◐"
	end
	if status == "restarting" then
		return "◍"
	end
	return "○"
end

local function build_rows(items)
	local rows = {}
	for _, c in ipairs(items) do
		local st = docker.to_status(c.status)
		table.insert(rows, {
			icon = status_icon(st),
			name = c.name or "-",
			image = c.image or "-",
			status = c.status or "-",
			ports = c.ports or "-",
			created = c.created_since or "-",
			_status = st,
			_item = {
				kind = "container",
				item = c,
			},
		})
	end
	return rows
end

---@param width number
---@return string[] lines, table line_map, table spans
function M.render(width)
	local items = state.containers.get_items()
	local rows = build_rows(items)

	local columns = {
		{ key = "icon", name = " ", width = 2, min_width = 2, max_width = 2, gap_after = 0 },
		{ key = "name", name = "Name", min_width = 18, hl = "DockyardName" },
		{ key = "image", name = "Image", min_width = 20, hl = "DockyardImage" },
		{ key = "status", name = "Status", min_width = 14, hl = "DockyardMuted" },
		{ key = "ports", name = "Ports", min_width = 12, hl = "DockyardPorts" },
		{ key = "created", name = "Created", min_width = 10, hl = "DockyardMuted" },
	}

	local lines, line_map, spans = table_view.render({
		columns = columns,
		rows = rows,
		width = width,
		margin = 1,
		cell_hl = function(row, column)
			if column.key == "icon" then
				return highlights.status_hl(row._status)
			end
			return nil
		end,
	})

	return lines, line_map, spans
end

return M
