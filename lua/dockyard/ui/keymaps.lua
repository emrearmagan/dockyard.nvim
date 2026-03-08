local M = {}

local ui_state = require("dockyard.ui.state")
local container_actions = require("dockyard.ui.actions.containers")

function M.get_item_at_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return ui_state.line_map[line]
end

local function on_container_action_done()
	M._handlers.refresh()
end

---@type { close: fun(), refresh: fun(), next_view: fun(), prev_view: fun(), open_help: fun() }
M._handlers = {
	close = function() end,
	refresh = function() end,
	next_view = function() end,
	prev_view = function() end,
	open_help = function() end,
}

---@param buf number
---@param handlers { close: fun(), refresh: fun(), next_view: fun(), prev_view: fun(), open_help?: fun() }
function M.register_global(buf, handlers)
	M._handlers = vim.tbl_extend("force", M._handlers, handlers or {})
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "q", function()
		M._handlers.close()
	end, opts)

	vim.keymap.set("n", "R", function()
		M._handlers.refresh()
	end, opts)

	vim.keymap.set("n", "j", "j", opts)
	vim.keymap.set("n", "k", "k", opts)

	vim.keymap.set("n", "<Tab>", function()
		M._handlers.next_view()
	end, opts)

	vim.keymap.set("n", "<S-Tab>", function()
		M._handlers.prev_view()
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

function M.register_view(buf, view)
	if view ~= "containers" then
		return
	end

	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "s", function()
		container_actions.toggle_start_stop(M.get_item_at_cursor(), on_container_action_done, vim.notify)
	end, opts)

	vim.keymap.set("n", "x", function()
		container_actions.stop(M.get_item_at_cursor(), on_container_action_done, vim.notify)
	end, opts)

	vim.keymap.set("n", "r", function()
		container_actions.restart(M.get_item_at_cursor(), on_container_action_done, vim.notify)
	end, opts)

	vim.keymap.set("n", "d", function()
		container_actions.remove(M.get_item_at_cursor(), on_container_action_done, vim.notify)
	end, opts)
end

function M.unregister_view(buf, view)
	if view ~= "containers" then
		return
	end

	pcall(vim.keymap.del, "n", "s", { buffer = buf })
	pcall(vim.keymap.del, "n", "x", { buffer = buf })
	pcall(vim.keymap.del, "n", "r", { buffer = buf })
	pcall(vim.keymap.del, "n", "d", { buffer = buf })
end

return M
