local M = {}

local collapsed_nodes = {}

local function copy(t)
	local res = {}
	for k, v in pairs(t) do res[k] = v end
	return res
end

function M.toggle_collapse(id, collapsed)
	if collapsed == nil then
		collapsed_nodes[id] = not collapsed_nodes[id]
	else
		collapsed_nodes[id] = collapsed
	end
end

local function get_tree_data()
	local networks_raw = require("dockyard.networks").all()
	local containers_raw = require("dockyard.containers").all()
	
	local tree = {}
	
	for _, net_raw in ipairs(networks_raw) do
		local net = copy(net_raw)
		net._is_network = true
		
		local is_collapsed = collapsed_nodes[net.id]
		if is_collapsed then
			net._indent = "󰅂 " 
		else
			net._indent = "󰅀 "
		end
		
		tree[#tree + 1] = net
		
		if not is_collapsed then
			-- Find containers connected to this network
			for _, cnt in ipairs(containers_raw) do
				local connected = false
				-- docker container ls --format networks returns a comma-separated list
				if cnt.networks then
					for n in string.gmatch(cnt.networks, "([^,]+)") do
						if n == net.name then
							connected = true
							break
						end
					end
				end

				if connected then
					local child = copy(cnt)
					child._indent = "  └─ "
					child._is_container = true
					
					local status_icon = "●"
					local status = (child.status or ""):lower()
					local icon_hl = status:find("up", 1, true) == 1 and "DockyardStatusRunning" or "DockyardStatusStopped"
					
					child._custom_icon_logic = true
					child.name_display = status_icon .. " " .. child.name
					child._name_icon_hl = { group = icon_hl, len = #status_icon }
					
					tree[#tree + 1] = child
				end
			end
		end
	end
	
	return tree
end

M.config = {
	has_icons = true,
	columns = {
		{ key = "name_display", label = "Network / Container", min_width = 30, weight = 2, hl = "DockyardName" },
		{ key = "driver", label = "Driver / Status", min_width = 20, weight = 1, hl = "DockyardMuted" },
		{ key = "scope", label = "Scope", min_width = 10, weight = 1, hl = "DockyardPorts" },
		{ key = "created", label = "Created", min_width = 20, weight = 1, hl = "DockyardMuted" },
	},
	get_row_icon = function(row)
		if row._is_network then
			return "󱂇", "DockyardImage"
		end
		local status = (row.status or ""):lower()
		if status:find("up", 1, true) == 1 then
			return "●", "DockyardStatusRunning"
		end
		return "●", "DockyardStatusStopped"
	end,
	transform_row = function(row)
		if row._is_network then
			row.name_display = row.name
		elseif row._is_container then
			row.driver = row.status
			row.scope = "-"
		end
		return row
	end,
	empty_message = "No networks found",
}

M.get_data = function()
	local data = get_tree_data()
	for _, row in ipairs(data) do
		M.config.transform_row(row)
	end
	return data
end

return M
