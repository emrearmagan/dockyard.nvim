local M = {}

local docker = require("dockyard.core.docker")

---@param item Image|nil
---@param on_done fun(res: { ok: boolean, error: string? }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.remove(item, on_done, notify)
	if not item then
		return
	end

	vim.ui.input({ prompt = "Remove image " .. tostring(item.repository or item.id) .. "? (y/n)" }, function(input)
		if input ~= "y" and input ~= "Y" then
			return
		end
		notify("Removing image " .. tostring(item.repository or item.id) .. "...", "info")

		docker.image_action(item.id, "rm", function(res)
			if not res.ok then
				notify("Image remove failed: " .. tostring(res.error), "error")
				if on_done then
					on_done(nil, false)
				end
				return
			end

			if on_done then
				on_done(res, true)
			end
			notify("Image removed", "success")
		end)
	end)
end

---@param on_done fun(res: { ok: boolean, error: string? }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.prune(on_done, notify)
	vim.ui.input({ prompt = "Prune all unused images? [y/N] " }, function(input)
		if not input or input:lower() ~= "y" then
			if on_done then
				on_done(nil, false)
			end
			return
		end

		notify("Pruning unused images...", "info")
		docker.image_prune(function(res)
			if not res.ok then
				notify("Image prune failed: " .. tostring(res.error), "error")
				if on_done then
					on_done(nil, false)
				end
				return
			end

			notify("Pruned unused images", "success")
			if on_done then
				on_done(res, true)
			end
		end)
	end)
end

return M
