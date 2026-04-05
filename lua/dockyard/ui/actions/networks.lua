local M = {}
local docker = require("dockyard.docker")

---@param item Network|nil
---@param on_done fun(res: { ok: boolean, error: string? }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.remove(item, on_done, notify)
	if not item then
		return
	end

	vim.ui.input({ prompt = "Remove network " .. tostring(item.name or item.id) .. "? (y/n)" }, function(input)
		if input ~= "y" and input ~= "Y" then
			return
		end
		notify("Removing network " .. tostring(item.name or item.id) .. "...", "info")

		docker.network_action(item.id, "rm", function(res)
			if not res.ok then
				notify("Network remove failed: " .. tostring(res.error), "error")
				if on_done then
					on_done(nil, false)
				end
				return
			end

			if on_done then
				on_done(res, true)
			end
			notify("Network removed", "success")
		end)
	end)
end

return M
