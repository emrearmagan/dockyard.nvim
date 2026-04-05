local docker = require("dockyard.docker")

local M = {}

---@param item table
---@param action string
---@param on_done fun(res: table|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: integer)
local function run_action(item, action, on_done, notify)
	docker.container_action(item.id, action, function(res)
		if not res.ok then
			notify("Docker " .. action .. " failed: " .. tostring(res.error), vim.log.levels.ERROR)
			if on_done then
				on_done(nil, false)
			end
			return
		end

		if on_done then
			on_done(res, true)
		end
	end)
end

---@param item table|nil
---@param on_done fun(res: table|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: integer)
function M.toggle_start_stop(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end
	local status = docker.to_status(item.status)
	run_action(item, status == "running" and "stop" or "start", on_done, notify)
end

---@param item table|nil
---@param on_done fun(res: table|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: integer)
function M.stop(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end
	run_action(item, "stop", on_done, notify)
end

---@param item table|nil
---@param on_done fun(res: table|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: integer)
function M.restart(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end
	run_action(item, "restart", on_done, notify)
end

---@param item table|nil
---@param on_done fun(res: table|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: integer)
function M.remove(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end
	vim.ui.input({ prompt = "Remove container " .. tostring(item.name or item.id) .. "? (y/n)" }, function(input)
		if input == "y" or input == "Y" then
			run_action(item, "rm", on_done, notify)
		end
	end)
end

return M
