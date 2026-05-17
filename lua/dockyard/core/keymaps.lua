local M = {}

---@alias DockyardKeymapValue string|string[]|false|nil

---@class DockyardUIKeymaps
---@field help? DockyardKeymapValue
---@field close? DockyardKeymapValue
---@field refresh? DockyardKeymapValue
---@field next_view? DockyardKeymapValue
---@field prev_view? DockyardKeymapValue
---@field toggle_node? DockyardKeymapValue
---@field open_details? DockyardKeymapValue
---@field open_panel? DockyardKeymapValue

---@class DockyardContainersKeymaps
---@field toggle_start_stop? DockyardKeymapValue
---@field stop? DockyardKeymapValue
---@field restart? DockyardKeymapValue
---@field remove? DockyardKeymapValue
---@field open_terminal? DockyardKeymapValue
---@field open_logs? DockyardKeymapValue

---@class DockyardImagesKeymaps
---@field remove? DockyardKeymapValue
---@field prune? DockyardKeymapValue

---@class DockyardNetworksKeymaps
---@field remove? DockyardKeymapValue

---@class DockyardVolumesKeymaps
---@field remove? DockyardKeymapValue

---@class DockyardLogLensKeymaps
---@field close? DockyardKeymapValue
---@field toggle_follow? DockyardKeymapValue
---@field toggle_raw? DockyardKeymapValue
---@field filter? DockyardKeymapValue
---@field clear_filter? DockyardKeymapValue
---@field open_detail? DockyardKeymapValue
---@field help? DockyardKeymapValue

---@class DockyardKeymapsConfig
---@field ui? DockyardUIKeymaps
---@field containers? DockyardContainersKeymaps
---@field images? DockyardImagesKeymaps
---@field networks? DockyardNetworksKeymaps
---@field volumes? DockyardVolumesKeymaps
---@field loglens? DockyardLogLensKeymaps

---@param value DockyardKeymapValue
---@return string[]|nil
local function normalize(value)
	if value == false or value == nil then
		return nil
	end
	if type(value) == "string" then
		if value == "" then
			return nil
		end
		return { value }
	end
	if type(value) ~= "table" then
		return nil
	end
	local out = {}
	for _, k in ipairs(value) do
		if type(k) == "string" and k ~= "" then
			table.insert(out, k)
		end
	end
	if #out == 0 then
		return nil
	end
	return out
end

---@param action_id string
---@return DockyardKeymapValue
local function from_config(action_id)
	local group, key = action_id:match("^([^.]+)%.(.+)$")
	if not group or not key then
		return nil
	end
	local cfg = require("dockyard.config").options.keymaps
	if type(cfg) ~= "table" then
		return nil
	end
	local section = cfg[group]
	if type(section) ~= "table" then
		return nil
	end
	return section[key]
end

---@param action_id string
---@return string[]|nil
function M.resolve(action_id)
	return normalize(from_config(action_id))
end

---@param action_id string
---@return string|string[]|nil
function M.key(action_id)
	local keys = M.resolve(action_id)
	if not keys then
		return nil
	end
	if #keys == 1 then
		return keys[1]
	end
	return keys
end

---@param action_id string
---@param base table
---@return table|nil
function M.item(action_id, base)
	local key = M.key(action_id)
	if key == nil then
		return nil
	end
	local out = vim.tbl_extend("force", {}, base)
	out.key = key
	return out
end

---@param action_id string
---@return table|nil
function M.removal(action_id)
	local key = M.key(action_id)
	if key == nil then
		return nil
	end
	return { key = key }
end

---@param list table
---@param entry table|nil
function M.push(list, entry)
	if entry ~= nil then
		table.insert(list, entry)
	end
end

---@param action_ids string[]
---@param builtins string[]
---@return table<string, string[]>
local function conflicts_for(action_ids, builtins)
	local seen = {}
	for _, action_id in ipairs(action_ids) do
		for _, key in ipairs(M.resolve(action_id) or {}) do
			seen[key] = seen[key] or {}
			seen[key][action_id] = true
		end
	end

	for _, key in ipairs(builtins or {}) do
		seen[key] = seen[key] or {}
		seen[key]["builtin:" .. key] = true
	end

	local conflicts = {}
	for key, set in pairs(seen) do
		local list = vim.tbl_keys(set)
		table.sort(list)
		if #list > 1 then
			conflicts[key] = list
		end
	end
	return conflicts
end

local UI_IDS = {
	"ui.help",
	"ui.close",
	"ui.refresh",
	"ui.next_view",
	"ui.prev_view",
	"ui.toggle_node",
	"ui.open_details",
	"ui.open_panel",
}

local CONTAINERS_IDS = {
	"containers.toggle_start_stop",
	"containers.stop",
	"containers.restart",
	"containers.remove",
	"containers.open_terminal",
	"containers.open_logs",
}

local IMAGES_IDS = {
	"images.remove",
	"images.prune",
}

local NETWORKS_IDS = {
	"networks.remove",
}

local VOLUMES_IDS = {
	"volumes.remove",
}

local LOGLENS_IDS = {
	"loglens.close",
	"loglens.toggle_follow",
	"loglens.toggle_raw",
	"loglens.filter",
	"loglens.clear_filter",
	"loglens.open_detail",
	"loglens.help",
}

local function concat(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for _, v in ipairs(t) do
			table.insert(out, v)
		end
	end
	return out
end

---@return table<string, table<string, string[]>>
function M.validate()
	return {
		ui = conflicts_for(UI_IDS, {}),
		containers = conflicts_for(concat(UI_IDS, CONTAINERS_IDS), {}),
		images = conflicts_for(concat(UI_IDS, IMAGES_IDS), {}),
		networks = conflicts_for(concat(UI_IDS, NETWORKS_IDS), {}),
		volumes = conflicts_for(concat(UI_IDS, VOLUMES_IDS), {}),
		loglens = conflicts_for(LOGLENS_IDS, {}),
	}
end

return M
