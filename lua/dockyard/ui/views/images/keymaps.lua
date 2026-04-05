local M = {}

local controller = require("dockyard.ui.views.images.controller")
local actions = require("dockyard.ui.actions.images")
local ui_state = require("dockyard.ui.state")

---@return ({ kind: "image", item: Image, key: string }|{ kind: "container", item: Container, key: string })|nil
local function get_typed_node_at_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local node = ui_state.line_map[line]
	if not node or not node.item then
		return nil
	end

	if node.kind == "image" then
		return { kind = "image", item = node.item, key = node.key }
	end

	if node.kind == "container" then
		return { kind = "container", item = node.item, key = node.key }
	end

	return nil
end

---@param buf number
---@param notify fun(msg:string,level?:"success"|"warn"|"error"|"info"|"loading")
---@param hooks { on_toggle?: fun(), on_remove_done?: fun(res: { ok: boolean, error?: string }|nil, ok: boolean), on_prune_done?: fun(res: { ok: boolean, error?: string }|nil, ok: boolean) }|nil
function M.setup(buf, notify, hooks)
	local opts = { buffer = buf, silent = true, nowait = true }
	vim.keymap.set("n", "d", function()
		local node = get_typed_node_at_cursor()
		if node and node.kind == "image" then
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

	vim.keymap.set("n", "<CR>", function()
		local node = get_typed_node_at_cursor()
		if node and node.kind == "image" then
			controller.toggle(node)
			if hooks and hooks.on_toggle then
				hooks.on_toggle()
			end
		end
	end, opts)

	vim.keymap.set("n", "K", function()
		local node = get_typed_node_at_cursor()
		if node then
			controller.open_details(node)
		end
	end, opts)
end

---@param buf number
function M.teardown(buf)
	pcall(vim.keymap.del, "n", "<CR>", { buffer = buf })
	pcall(vim.keymap.del, "n", "d", { buffer = buf })
	pcall(vim.keymap.del, "n", "P", { buffer = buf })
	pcall(vim.keymap.del, "n", "K", { buffer = buf })
end

return M
