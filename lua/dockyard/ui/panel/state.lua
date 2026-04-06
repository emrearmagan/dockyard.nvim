---@alias DockyardPanelNode
---| { kind: "container", item: Container, key: string }
---| { kind: "image", item: Image, key: string }
---| { kind: "network", item: Network, key: string }
---| { kind: "volume", item: Volume, key: string }

--- @class DockyardPanelState
--- @field current_node DockyardPanelNode|nil
--- @field current_tab "container"|"image"|"volume"|"network"|nil
--- @field buf number|nil
--- @field win number|nil
--- @field line_map table

--- @class DockyardPanelState
local M = {
	current_node = nil,
	current_tab = nil,
	buf = nil,
	win = nil,
	line_map = {},
}

---@param node table|nil
function M.set_current(node)
	M.current_node = node
	M.current_tab = nil
	M.line_map = {}
end

---@param tab string
function M.set_tab(tab)
	M.current_tab = tab
	M.line_map = {}
end

function M.reset()
	M.current_node = nil
	M.current_tab = nil
	M.line_map = {}
end

return M
