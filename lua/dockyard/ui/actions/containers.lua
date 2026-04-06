local docker = require("dockyard.core.docker")

local M = {}

---@param item Container
---@param action string
---@param on_done fun(res: { ok: boolean, error: string? }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
local function run_action(item, action, on_done, notify)
	notify("Docker " .. action .. "...", "info")
	docker.container_action(item.id, action, function(res)
		if not res.ok then
			notify("Docker " .. action .. " failed: " .. tostring(res.error), "error")
			if on_done then
				on_done(nil, false)
			end
			return
		end

		if on_done then
			on_done(res, true)
		end
		notify("Docker " .. action .. " succeeded", "success")
	end)
end

---@param item Container|nil
---@param on_done fun(res: { ok: boolean, error?: string }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.toggle_start_stop(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", "warn")
		return
	end

	run_action(item, item.status == "running" and "stop" or "start", on_done, notify)
end

---@param item Container|nil
---@param on_done fun(res: { ok: boolean, error?: string }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.stop(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", "warn")
		return
	end
	run_action(item, "stop", on_done, notify)
end

---@param item Container|nil
---@param on_done fun(res: { ok: boolean, error?: string }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.restart(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", "warn")
		return
	end
	run_action(item, "restart", on_done, notify)
end

---@param item Container|nil
---@param on_done fun(res: { ok: boolean, error?: string }|nil, ok: boolean)|nil
---@param notify fun(msg: string, level?: "success"|"warn"|"error"|"info"|"loading")
function M.remove(item, on_done, notify)
	if not item then
		notify("Dockyard: no container selected", "warn")
		return
	end
	vim.ui.input({ prompt = "Remove container " .. tostring(item.name or item.id) .. "? (y/n)" }, function(input)
		if input == "y" or input == "Y" then
			run_action(item, "rm", on_done, notify)
		end
	end)
end

return M
