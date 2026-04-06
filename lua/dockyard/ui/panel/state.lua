---@alias DockyardPanelNode
---| { kind: "container", item: Container, key: string }
---| { kind: "image", item: Image, key: string }
---| { kind: "network", item: Network, key: string }
---| { kind: "volume", item: Volume, key: string }

--- @class DockyardPanelState
--- @field current_node DockyardPanelNode|nil
--- @field current_panel "container"|"image"|"volume"|"network"|nil
--- @field buf number|nil
--- @field win number|nil
--- @field line_map table
local M = {
	current_node = nil,
	current_panel = nil,
	buf = nil,
	win = nil,
	line_map = {},
}

---@param node DockyardPanelNode|nil
function M.set_current(node)
	M.current_node = node
	M.current_panel = node and node.kind or nil
	M.line_map = {}
end

function M.reset()
	M.current_node = nil
	M.current_panel = nil
	M.line_map = {}
end

return M
