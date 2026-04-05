---@class DockyardNetworksViewState
---@field expanded table<string, boolean>
---@field spinner_frame string|nil
---@field poll_spinner SpinnerInstance|nil

---@class DockyardNetworksViewState
local M = {
	expanded = {},
	spinner_frame = nil,
	poll_spinner = nil,
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
