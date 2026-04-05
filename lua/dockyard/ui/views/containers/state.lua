---@class DockyardContainersViewState
---@field last_rendered_at integer|nil
---@field spinner_frame string|nil
---@field poll_spinner SpinnerInstance|nil
---@field expanded table<string, boolean>

---@class DockyardContainersViewState
local M = {
	last_rendered_at = nil,
	spinner_frame = nil,
	poll_spinner = nil,
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
