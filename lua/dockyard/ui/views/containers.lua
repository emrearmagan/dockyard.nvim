local M = {}

local state = require("dockyard.state")
local table_view = require("dockyard.ui.components.table")
local highlights = require("dockyard.ui.highlights")

local function to_status(raw)
	raw = tostring(raw or ""):lower()
	if raw:find("up", 1, true) then
		return "running"
	end
	if raw:find("paused", 1, true) then
		return "paused"
	end
	if raw:find("restarting", 1, true) then
		return "restarting"
	end
	if raw:find("dead", 1, true) then
		return "dead"
	end
	return "stopped"
end

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
		local st = to_status(c.status)
		table.insert(rows, {
			icon = status_icon(st),
			name = c.name or "-",
			image = c.image or "-",
			status = c.status or "-",
			ports = c.ports or "-",
			created = c.created_since or "-",
			_status = st,
			_item = c,
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
