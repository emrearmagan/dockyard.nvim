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
	local images_raw = require("dockyard.images").all()
	local containers_raw = require("dockyard.containers").all()
	
	local tree = {}
	local containers = {}
	for _, c in ipairs(containers_raw) do
		containers[#containers + 1] = copy(c)
	end

	for _, img_raw in ipairs(images_raw) do
		local img = copy(img_raw)
		img._is_image = true
		
		local is_collapsed = collapsed_nodes[img.id]
		if is_collapsed then
			img._indent = "󰅂 " -- Collapsed icon
		else
			img._indent = "󰅀 " -- Expanded icon
		end
		
		tree[#tree + 1] = img
		
		if not is_collapsed then
			-- Find child containers
			for _, cnt in ipairs(containers) do
				if cnt.image == img.repository .. ":" .. img.tag or cnt.image == img.id then
					cnt._indent = "  └─ "
					cnt._is_container = true
					-- Add the status icon directly to the name for children
					local status_icon = "●"
					local status = (cnt.status or ""):lower()
					local icon_hl = status:find("up", 1, true) == 1 and "DockyardStatusRunning" or "DockyardStatusStopped"
					
					cnt._custom_icon_logic = true
					cnt.repository = status_icon .. " " .. cnt.name
					cnt._name_icon_hl = { group = icon_hl, len = #status_icon }
					
					tree[#tree + 1] = cnt
				end
			end
		end
	end
	
	-- Handle orphaned containers
	for _, cnt in ipairs(containers) do
		if not cnt._is_container then
			tree[#tree + 1] = cnt
		end
	end
	
	return tree
end

M.config = {
	has_icons = true,
	columns = {
		{ key = "repository", label = "Repository / Name", min_width = 25, weight = 2, hl = "DockyardName" },
		{ key = "tag", label = "Tag / Status", min_width = 20, weight = 1, hl = "DockyardMuted" },
		{ key = "size", label = "Size", min_width = 10, weight = 1, hl = "DockyardPorts" },
		{ key = "created_since", label = "Created", min_width = 15, weight = 1, hl = "DockyardMuted" },
	},
	get_row_icon = function(row)
		if row._is_image then
			return "󰏗", "DockyardImage"
		end
		local status = (row.status or ""):lower()
		if status:find("up", 1, true) == 1 then
			return "●", "DockyardStatusRunning"
		end
		return "●", "DockyardStatusStopped"
	end,
	transform_row = function(row)
		if row._is_container then
			if not row._custom_icon_logic then
				row.repository = row.name
			end
			row.tag = row.status
			row.size = "-"
		end
		return row
	end,
	empty_message = "No images found",
}

M.get_data = function()
	local data = get_tree_data()
	for _, row in ipairs(data) do
		M.config.transform_row(row)
	end
	return data
end

return M
