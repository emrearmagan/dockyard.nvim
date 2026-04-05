local M = {}

local controller = require("dockyard.ui.views.containers.controller")
local actions = require("dockyard.ui.actions.containers")

local function get_node_at_cursor()
	local ui_state = require("dockyard.ui.state")
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return ui_state.line_map[line]
end

---@return ({ kind: "container", item: Container, key: string }|{ kind: "compose_project", item: Container, key: string })|nil
local function get_item_at_cursor()
	local node = get_node_at_cursor()
	if not node then
		return nil
	end

	if node.kind == "container" and node.item then
		return { kind = "container", item = node.item, key = node.item.id }
	elseif node.kind == "compose_project" then
		return { kind = "compose_project", item = node, key = node.key }
	end

	return nil
end

---@param buf number
---@param notify fun(msg:string,level?:"success"|"warn"|"error"|"info"|"loading")
---@param hooks { on_done?: fun(res: { ok: boolean, error?: string }|nil, ok: boolean) }|nil
function M.setup(buf, notify, hooks)
	local opts = { buffer = buf, silent = true, nowait = true }
	local on_done = function(res, ok)
		if hooks and hooks.on_done then
			hooks.on_done(res, ok)
		end
	end

	vim.keymap.set("n", "<CR>", function()
		local node = get_item_at_cursor()
		if node and node.kind == "compose_project" then
			controller.toggle(node.item)
			on_done(nil, true)
		end
	end, opts)

	vim.keymap.set("n", "s", function()
		local item = get_item_at_cursor()
		if item then
			actions.toggle_start_stop(item.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "x", function()
		local item = get_item_at_cursor()
		if item then
			actions.stop(item.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "r", function()
		local item = get_item_at_cursor()
		if item then
			actions.restart(item.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "d", function()
		local item = get_item_at_cursor()
		if item then
			actions.remove(item.item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "T", function()
		local item = get_item_at_cursor()
		if item then
			controller.open_terminal(item.item)
		end
	end, opts)

	vim.keymap.set("n", "L", function()
		local item = get_item_at_cursor()
		if item then
			controller.open_logs(item.item)
		end
	end, opts)

	vim.keymap.set("n", "K", function()
		local item = get_item_at_cursor()
		if item then
			controller.open_details(item.item)
		end
	end, opts)
		end
	end, opts)
end

---@param buf number
function M.teardown(buf)
	pcall(vim.keymap.del, "n", "<CR>", { buffer = buf })
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
