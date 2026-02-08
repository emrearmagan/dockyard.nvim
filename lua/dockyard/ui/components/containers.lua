local M = {}

M.get_data = function()
	return require("dockyard.containers").all()
end

M.config = {
	has_icons = true,
	columns = {
		{ key = "name", label = "Name", min_width = 18, weight = 2, hl = "DockyardName" },
		{ key = "image", label = "Image", min_width = 20, weight = 2, hl = "DockyardImage" },
		{ key = "status", label = "Status", min_width = 14, weight = 1, hl = "DockyardMuted" },
		{ key = "ports", label = "Ports", min_width = 20, weight = 2, hl = "DockyardPorts" },
		{ key = "created_since", label = "Created", min_width = 18, weight = 1, hl = "DockyardMuted" },
	},
	get_row_icon = function(row)
		local status = (row.status or ""):lower()
		if status:find("up", 1, true) == 1 then
			return "●", "DockyardStatusRunning"
		end
		return "●", "DockyardStatusStopped"
	end,
	empty_message = "No running containers",
}

return M
