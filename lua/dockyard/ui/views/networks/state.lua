---@class DockyardNetworksViewState
---@field expanded table<string, boolean>

---@class DockyardNetworksViewState
local M = {
	expanded = {},
}

function M.toggle(key)
	local current = M.expanded[key]
	if current == nil then
		current = true
	end
	M.expanded[key] = not current
end

function M.reset()
	M.expanded = {}
end

return M
