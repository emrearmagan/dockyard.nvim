local M = {}

local docker = require("dockyard.docker")

---@param node table|nil
---@param on_done fun(res: table|nil, ok: boolean)
---@param notify fun(msg: string, level?: integer)|nil
function M.remove(node, on_done, notify)
	if not node or node.kind ~= "image" or not node.item then
		return
	end

	vim.ui.input({ prompt = "Remove image " .. tostring(node.item.repository or node.item.id) .. "? (y/n)" }, function(input)
		if input ~= "y" and input ~= "Y" then
			return
		end

		docker.image_action(node.item.id, "rm", function(res)
			if not res.ok then
				(notify or vim.notify)("Image remove failed: " .. tostring(res.error), vim.log.levels.ERROR)
				on_done(nil, false)
				return
			end

			on_done(res, true)
		end)
	end)
end

---@param on_done fun(res: table|nil, ok: boolean)
---@param notify fun(msg: string, level?: integer)|nil
function M.prune(on_done, notify)
	docker.image_prune(function(res)
		if not res.ok then
			(notify or vim.notify)("Image prune failed: " .. tostring(res.error), vim.log.levels.ERROR)
			on_done(nil, false)
			return
		end

		(notify or vim.notify)("Pruned dangling images", vim.log.levels.INFO)
		on_done(res, true)
	end)
end

return M
