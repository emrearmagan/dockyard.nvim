-- Global tracker for processes running inside Docker containers that need
-- explicit cleanup on exit. Normal stream stop() handles this at runtime,
-- but VimLeavePre ensures cleanup even when Neovim exits unexpectedly
-- (terminal closed, :qa!, SIGHUP) — uses vim.fn.system so it runs synchronously.

local M = {}

local _tracked = {} -- { container_id: string, pid: number }

--- Track an inner process PID. Returns an untrack function to call on normal stop.
---@param container_id string
---@param pid number
---@return fun() untrack
function M.track(container_id, pid)
	table.insert(_tracked, { container_id = container_id, pid = pid })
	return function()
		for i, t in ipairs(_tracked) do
			if t.container_id == container_id and t.pid == pid then
				table.remove(_tracked, i)
				return
			end
		end
	end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = vim.api.nvim_create_augroup("DockyardJobCleanup", { clear = true }),
	callback = function()
		for _, t in ipairs(_tracked) do
			pcall(vim.fn.system, string.format("docker exec %s kill -9 %d 2>/dev/null", t.container_id, t.pid))
		end
		_tracked = {}
	end,
})

return M
