local M = {}

local controller = require("dockyard.ui.views.containers.controller")
local actions = require("dockyard.ui.actions.containers")

local function get_container_node_at_cursor()
	local ui_state = require("dockyard.ui.state")
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local node = ui_state.line_map[line]
	if not node then
		return nil
	end

	if node.kind == "container" and node.item then
		return { kind = "container", item = node.item }
	end

	return nil
end

---@param buf number
---@param notify fun(msg:string,level?:integer)
---@param hooks { on_done?: fun(res: table|nil, ok: boolean) }|nil
function M.setup(buf, notify, hooks)
	local opts = { buffer = buf, silent = true, nowait = true }
	local on_done = function(_, ok)
		if hooks and hooks.on_done then
			hooks.on_done(nil, ok)
		end
	end

	vim.keymap.set("n", "s", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			actions.toggle_start_stop(node.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "x", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			actions.stop(node.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "r", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			actions.restart(node.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "d", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			actions.remove(node.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "T", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			controller.open_terminal(node)
		end
	end, opts)

	vim.keymap.set("n", "L", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			controller.open_logs(node)
		end
	end, opts)

	vim.keymap.set("n", "K", function()
		local node = get_container_node_at_cursor()
		if node and node.item then
			controller.open_details(node)
		end
	end, opts)
end

---@param buf number
function M.teardown(buf)
	pcall(vim.keymap.del, "n", "s", { buffer = buf })
	pcall(vim.keymap.del, "n", "x", { buffer = buf })
	pcall(vim.keymap.del, "n", "r", { buffer = buf })
	pcall(vim.keymap.del, "n", "d", { buffer = buf })
	pcall(vim.keymap.del, "n", "T", { buffer = buf })
	pcall(vim.keymap.del, "n", "L", { buffer = buf })
	pcall(vim.keymap.del, "n", "K", { buffer = buf })
	controller.on_teardown()
end

return M
