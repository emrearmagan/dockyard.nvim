local M = {}

local controller = require("dockyard.ui.views.images.controller")
local actions = require("dockyard.ui.actions.images")
local ui_state = require("dockyard.ui.state")

local function get_node_at_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	return ui_state.line_map[line]
end

local function get_image_node_at_cursor()
	local node = get_node_at_cursor()
	if not node then
		return nil
	end

	if node.kind == "image" then
		return node
	end

	return nil
end

---@param buf number
---@param notify fun(msg:string,level?:integer)
---@param hooks { on_toggle?: fun(), on_remove_done?: fun(res: { ok: boolean, error?: string }|nil, ok: boolean), on_prune_done?: fun(res: { ok: boolean, error?: string }|nil, ok: boolean) }|nil
function M.setup(buf, notify, hooks)
	local opts = { buffer = buf, silent = true, nowait = true }
	local function open_details_at_cursor()
		local node = get_node_at_cursor()
		if node then
			controller.open_details(node)
		end
	end

	vim.keymap.set("n", "<CR>", function()
		local node = get_image_node_at_cursor()
		if node then
			controller.toggle(node)
			if hooks and hooks.on_toggle then
				hooks.on_toggle()
			end
		end
	end, opts)

	vim.keymap.set("n", "d", function()
		local node = get_image_node_at_cursor()
		if node then
			actions.remove(node.item, function(res, ok)
				if hooks and hooks.on_remove_done then
					hooks.on_remove_done(res, ok)
				end
			end, notify)
		end
	end, opts)

	vim.keymap.set("n", "P", function()
		actions.prune(function(res, ok)
			if hooks and hooks.on_prune_done then
				hooks.on_prune_done(res, ok)
			end
		end, notify)
	end, opts)

	vim.keymap.set("n", "K", open_details_at_cursor, opts)
end

---@param buf number
function M.teardown(buf)
	pcall(vim.keymap.del, "n", "<CR>", { buffer = buf })
	pcall(vim.keymap.del, "n", "d", { buffer = buf })
	pcall(vim.keymap.del, "n", "P", { buffer = buf })
	pcall(vim.keymap.del, "n", "K", { buffer = buf })
end

return M
