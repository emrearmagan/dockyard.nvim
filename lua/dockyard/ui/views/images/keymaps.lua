local M = {}

local controller = require("dockyard.ui.views.images.controller")
local actions = require("dockyard.ui.actions.images")
local ui_state = require("dockyard.ui.state")
local help = require("dockyard.ui.popups.help")
local resolver = require("dockyard.core.keymaps")

local GROUP = "Images"
local INDEX = 30

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
	local items = {}

	resolver.push(
		items,
		resolver.item("ui.toggle_node", {
			desc = "Expand / Collapse image",
			callback = function()
				local node = get_typed_node_at_cursor()
				if node and node.kind == "image" then
					controller.toggle(node)
					if hooks and hooks.on_toggle then
						hooks.on_toggle()
					end
				end
			end,
			index = 1,
		})
	)
	resolver.push(
		items,
		resolver.item("images.remove", {
			desc = "Remove selected image",
			callback = function()
				local node = get_typed_node_at_cursor()
				if node and node.kind == "image" then
					actions.remove(node.item, function(res, ok)
						if hooks and hooks.on_remove_done then
							hooks.on_remove_done(res, ok)
						end
					end, notify)
				end
			end,
			index = 2,
		})
	)
	resolver.push(
		items,
		resolver.item("images.prune", {
			desc = "Prune dangling images",
			callback = function()
				actions.prune(function(res, ok)
					if hooks and hooks.on_prune_done then
						hooks.on_prune_done(res, ok)
					end
				end, notify)
			end,
			index = 3,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.open_details", {
			desc = "Open inspect popup",
			callback = function()
				local node = get_typed_node_at_cursor()
				if node then
					controller.open_details(node)
				end
			end,
			index = 4,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.open_panel", {
			desc = "Open detail panel",
			callback = function()
				local node = get_typed_node_at_cursor()
				if node then
					require("dockyard.ui.panel").open(node)
				end
			end,
			index = 5,
		})
	)

	help.register(GROUP, items, { buffer = buf, index = INDEX })
end

---@param buf number
function M.teardown(buf)
	local items = {}
	resolver.push(items, resolver.removal("ui.toggle_node"))
	resolver.push(items, resolver.removal("images.remove"))
	resolver.push(items, resolver.removal("images.prune"))
	resolver.push(items, resolver.removal("ui.open_details"))
	resolver.push(items, resolver.removal("ui.open_panel"))
	help.remove(GROUP, items, { buffer = buf })
end

return M
