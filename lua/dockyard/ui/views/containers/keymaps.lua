local M = {}

local controller = require("dockyard.ui.views.containers.controller")
local actions = require("dockyard.ui.actions.containers")

---@return Container|nil
local function get_container_item_at_cursor()
	local ui_state = require("dockyard.ui.state")
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local node = ui_state.line_map[line]
	if not node then
		return nil
	end

	if node.kind == "container" and node.item then
		return node.item
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

	vim.keymap.set("n", "s", function()
		local item = get_container_item_at_cursor()
		if item then
			actions.toggle_start_stop(item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "x", function()
		local item = get_container_item_at_cursor()
		if item then
			actions.stop(item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "r", function()
		local item = get_container_item_at_cursor()
		if item then
			actions.restart(item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "d", function()
		local item = get_container_item_at_cursor()
		if item then
			actions.remove(item, on_done, notify)
		end
	end, opts)

	vim.keymap.set("n", "T", function()
		local item = get_container_item_at_cursor()
		if item then
			controller.open_terminal(item)
		end
	end, opts)

	vim.keymap.set("n", "L", function()
		local item = get_container_item_at_cursor()
		if item then
			controller.open_logs(item)
		end
	end, opts)

	vim.keymap.set("n", "K", function()
		local item = get_container_item_at_cursor()
		if item then
			controller.open_details(item)
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
