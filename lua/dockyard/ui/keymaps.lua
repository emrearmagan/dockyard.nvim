local M = {}

local navigation = require("dockyard.ui.navigation")

---@param buf number
---@param handlers { close: fun(), refresh: fun(), next_view: fun(), prev_view: fun(), open_help?: fun() }
function M.register_global(buf, handlers)
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "q", function()
		handlers.close()
	end, opts)

	vim.keymap.set("n", "R", function()
		handlers.refresh()
	end, opts)

	vim.keymap.set("n", "j", navigation.down, opts)
	vim.keymap.set("n", "k", navigation.up, opts)

	vim.keymap.set("n", "<Tab>", function()
		handlers.next_view()
	end, opts)

	vim.keymap.set("n", "<S-Tab>", function()
		handlers.prev_view()
	end, opts)

	vim.keymap.set("n", "?", function()
		handlers.open_help()
	end, opts)
end

function M.unregister_global(buf)
	pcall(vim.keymap.del, "n", "q", { buffer = buf })
	pcall(vim.keymap.del, "n", "R", { buffer = buf })
	pcall(vim.keymap.del, "n", "j", { buffer = buf })
	pcall(vim.keymap.del, "n", "k", { buffer = buf })
	pcall(vim.keymap.del, "n", "<Tab>", { buffer = buf })
	pcall(vim.keymap.del, "n", "<S-Tab>", { buffer = buf })
	pcall(vim.keymap.del, "n", "?", { buffer = buf })
end

return M
