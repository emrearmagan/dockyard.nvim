local M = {}

local ICONS = {
	container = {
		running = "●",
		paused = "◐",
		starting = "◍",
		restarting = "◍",
		removing = "◍",
		created = "○",
		exited = "○",
		dead = "○",
		unknown = "○",
		fallback = "○",
	},
	image = {
		default = "󰏗",
		fallback = "󰏗",
	},
	network = {
		default = "󱂇",
		fallback = "󱂇",
	},
	view = {
		containers = "󰏗",
		images = "",
		networks = "󰖩",
		fallback = "•",
	},
	global = {
		fallback = "•",
	},
}

---@param name string|nil
---@return string
local function normalize(name)
	return (tostring(name or ""):lower():gsub("[-%s_]", ""))
end

---@param name string|nil
---@return string
function M.container_icon(name)
	local key = normalize(name)
	return ICONS.container[key] or ICONS.container.fallback
end

---@param name string|nil
---@return string
function M.image_icon(name)
	local key = normalize(name)
	return ICONS.image[key] or ICONS.image.fallback
end

---@param name string|nil
---@return string
function M.network_icon(name)
	local key = normalize(name)
	return ICONS.network[key] or ICONS.network.fallback
end

---@param name string|nil
---@return string
function M.view_icon(name)
	local key = normalize(name)
	return ICONS.view[key] or ICONS.view.fallback
end

---@param name string|nil
---@return string
function M.icon(name)
	local key = normalize(name)
	return ICONS.global[key] or ICONS.global.fallback
end

return M
