local M = {}

local controller = require("dockyard.ui.views.volumes.controller")
local actions = require("dockyard.ui.actions.volumes")
local ui_state = require("dockyard.ui.state")
local help = require("dockyard.ui.popups.help")

local GROUP = "Volumes"
local INDEX = 50

local function get_volume_node_at_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local node = ui_state.line_map[line]
	if not node or node.kind ~= "volume" then
		return nil
	end
	return node
end

---@param buf number
---@param notify fun(msg:string,level?:"success"|"warn"|"error"|"info"|"loading")
---@param hooks { on_remove_done?: fun(res: { ok: boolean, error?: string }|nil, ok: boolean) }|nil
function M.setup(buf, notify, hooks)
	local items = {
		{
			key = "d",
			desc = "Remove selected volume",
			callback = function()
				local node = get_volume_node_at_cursor()
				if node then
					actions.remove(node.item, function(res, ok)
						if hooks and hooks.on_remove_done then
							hooks.on_remove_done(res, ok)
						end
					end, notify)
				end
			end,
			index = 1,
		},
		{
			key = "K",
			desc = "Open inspect popup",
			callback = function()
				local node = get_volume_node_at_cursor()
				if node then
					controller.open_details(node)
				end
			end,
			index = 2,
		},
		{
			key = "p",
			desc = "Open detail panel",
			callback = function()
				local node = get_volume_node_at_cursor()
				if node then
					require("dockyard.ui.panel").open(node)
				end
			end,
			index = 3,
		},
	}

	help.register(GROUP, items, { buffer = buf, index = INDEX })
end

---@param buf number
function M.teardown(buf)
	local items = {
		{ key = "d" },
		{ key = "K" },
		{ key = "p" },
	}
	help.remove(GROUP, items, { buffer = buf })
end

return M
