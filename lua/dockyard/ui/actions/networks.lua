local M = {}
local docker = require("dockyard.docker")

---@param node table|nil
---@param on_done fun(res: table|nil, ok: boolean)
---@param notify fun(msg: string, level?: integer)|nil
function M.remove(node, on_done, notify)
	if not node or node.kind ~= "network" or not node.item then
		return
	end

	vim.ui.input({ prompt = "Remove network " .. tostring(node.item.name or node.item.id) .. "? (y/n)" }, function(input)
		if input ~= "y" and input ~= "Y" then
			return
		end

		docker.network_action(node.item.id, "rm", function(res)
			if not res.ok then
				(notify or vim.notify)("Network remove failed: " .. tostring(res.error), vim.log.levels.ERROR)
				on_done(nil, false)
				return
			end
			on_done(res, true)
		end)
	end)
end

return M
