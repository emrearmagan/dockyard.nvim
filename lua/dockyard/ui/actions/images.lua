local M = {}

local docker = require("dockyard.docker")

---@param item Image|nil
---@param on_done fun(res: { ok: boolean, error?: string }|nil, ok: boolean)
---@param notify fun(msg: string, level?: integer)|nil
function M.remove(item, on_done, notify)
	if not item then
		return
	end

	vim.ui.input({ prompt = "Remove image " .. tostring(item.repository or item.id) .. "? (y/n)" }, function(input)
		if input ~= "y" and input ~= "Y" then
			return
		end

		docker.image_action(item.id, "rm", function(res)
			if not res.ok then
				(notify or vim.notify)("Image remove failed: " .. tostring(res.error), vim.log.levels.ERROR)
				on_done(nil, false)
				return
			end

			on_done(res, true)
		end)
	end)
end

---@param on_done fun(res: { ok: boolean, error?: string }|nil, ok: boolean)
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
