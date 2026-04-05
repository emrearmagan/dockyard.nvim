local M = {}

local controller = require("dockyard.ui.views.volumes.controller")
local actions = require("dockyard.ui.actions.volumes")
local ui_state = require("dockyard.ui.state")

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
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "d", function()
		local node = get_volume_node_at_cursor()
		if node then
			actions.remove(node.item, function(res, ok)
				if hooks and hooks.on_remove_done then
					hooks.on_remove_done(res, ok)
				end
			end, notify)
		end
	end, opts)

	vim.keymap.set("n", "o", function()
		local node = get_volume_node_at_cursor()
		if node then
			controller.open_in_vim(node)
		end
	end, opts)

	vim.keymap.set("n", "p", function()
		local node = get_volume_node_at_cursor()
		if node then
			require("dockyard.ui.panel").open(node)
		end
	end, opts)
end

---@param buf number
function M.teardown(buf)
	pcall(vim.keymap.del, "n", "d", { buffer = buf })
	pcall(vim.keymap.del, "n", "o", { buffer = buf })
	pcall(vim.keymap.del, "n", "p", { buffer = buf })
end

return M
