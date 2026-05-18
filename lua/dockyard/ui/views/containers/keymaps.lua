local M = {}

local controller = require("dockyard.ui.views.containers.controller")
local actions = require("dockyard.ui.actions.containers")
local help = require("dockyard.ui.popups.help")
local resolver = require("dockyard.core.keymaps")

local GROUP = "Containers"
local INDEX = 20

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
	local on_done = function(res, ok)
		if hooks and hooks.on_done then
			hooks.on_done(res, ok)
		end
	end

	local items = {}

	resolver.push(
		items,
		resolver.item("ui.toggle_node", {
			desc = "Expand / Collapse compose project",
			callback = function()
				local node = get_item_at_cursor()
				if node and node.kind == "compose_project" then
					controller.toggle(node.item)
					on_done(nil, true)
				end
			end,
			index = 1,
		})
	)
	resolver.push(
		items,
		resolver.item("containers.toggle_start_stop", {
			desc = "Toggle Start / Stop",
			callback = function()
				local item = get_item_at_cursor()
				if item then
					actions.toggle_start_stop(item.item, on_done, notify)
				end
			end,
			index = 2,
		})
	)
	resolver.push(
		items,
		resolver.item("containers.stop", {
			desc = "Stop container",
			callback = function()
				local item = get_item_at_cursor()
				if item then
					actions.stop(item.item, on_done, notify)
				end
			end,
			index = 3,
		})
	)
	resolver.push(
		items,
		resolver.item("containers.restart", {
			desc = "Restart container",
			callback = function()
				local item = get_item_at_cursor()
				if item then
					actions.restart(item.item, on_done, notify)
				end
			end,
			index = 4,
		})
	)
	resolver.push(
		items,
		resolver.item("containers.remove", {
			desc = "Remove container",
			callback = function()
				local item = get_item_at_cursor()
				if item then
					actions.remove(item.item, on_done, notify)
				end
			end,
			index = 5,
		})
	)
	resolver.push(
		items,
		resolver.item("containers.open_terminal", {
			desc = "Open terminal",
			callback = function()
				local item = get_item_at_cursor()
				if item then
					controller.open_terminal(item.item)
				end
			end,
			index = 6,
		})
	)
	resolver.push(
		items,
		resolver.item("containers.open_logs", {
			desc = "Open logs",
			callback = function()
				local item = get_item_at_cursor()
				if item then
					controller.open_logs(item.item)
				end
			end,
			index = 7,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.open_details", {
			desc = "Open inspect popup",
			callback = function()
				local item = get_item_at_cursor()
				if item and item.kind == "container" then
					controller.open_details(item.item)
				end
			end,
			index = 8,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.open_panel", {
			desc = "Open detail panel",
			callback = function()
				local node = get_item_at_cursor()
				if node then
					require("dockyard.ui.panel").open(node)
				end
			end,
			index = 9,
		})
	)

	help.register(GROUP, items, { buffer = buf, index = INDEX })
end

---@param buf number
function M.teardown(buf)
	local items = {}
	resolver.push(items, resolver.removal("ui.toggle_node"))
	resolver.push(items, resolver.removal("containers.toggle_start_stop"))
	resolver.push(items, resolver.removal("containers.stop"))
	resolver.push(items, resolver.removal("containers.restart"))
	resolver.push(items, resolver.removal("containers.remove"))
	resolver.push(items, resolver.removal("containers.open_terminal"))
	resolver.push(items, resolver.removal("containers.open_logs"))
	resolver.push(items, resolver.removal("ui.open_details"))
	resolver.push(items, resolver.removal("ui.open_panel"))
	help.remove(GROUP, items, { buffer = buf })
	controller.on_teardown()
end

return M
