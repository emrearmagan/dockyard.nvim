local M = {}

---@param buf number
---@param state LogLensState
---@param on_close fun()
function M.attach(buf, state, on_close)
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "q", function()
		on_close()
	end, opts)
end

return M
