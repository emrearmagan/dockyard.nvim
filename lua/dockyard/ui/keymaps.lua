local M = {}

local navigation = require("dockyard.ui.navigation")
local help = require("dockyard.ui.popups.help")
local resolver = require("dockyard.core.keymaps")

local GROUP = "General"
local INDEX = 10

---@param buf number
---@param handlers { close: fun(), refresh: fun(), next_view: fun(), prev_view: fun(), open_help?: fun() }
function M.register_global(buf, handlers)
	local items = {
		{
			key = "j",
			desc = "Move down",
			callback = navigation.down,
			hidden = true,
		},
		{
			key = "k",
			desc = "Move up",
			callback = navigation.up,
			hidden = true,
		},
	}

	resolver.push(
		items,
		resolver.item("ui.close", {
			desc = "Close Dockyard",
			callback = function()
				handlers.close()
			end,
			index = 1,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.refresh", {
			desc = "Refresh current view",
			callback = function()
				handlers.refresh()
			end,
			index = 2,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.next_view", {
			desc = "Next tab",
			callback = function()
				handlers.next_view()
			end,
			index = 3,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.prev_view", {
			desc = "Previous tab",
			callback = function()
				handlers.prev_view()
			end,
			index = 4,
		})
	)
	resolver.push(
		items,
		resolver.item("ui.help", {
			desc = "Toggle this help popup",
			callback = function()
				if handlers.open_help then
					handlers.open_help()
				else
					help.toggle({ buffer = buf })
				end
			end,
			index = 99,
		})
	)

	help.register(GROUP, items, { buffer = buf, index = INDEX })
end

function M.unregister_global(buf)
	local items = {
		{ key = "j" },
		{ key = "k" },
	}
	resolver.push(items, resolver.removal("ui.close"))
	resolver.push(items, resolver.removal("ui.refresh"))
	resolver.push(items, resolver.removal("ui.next_view"))
	resolver.push(items, resolver.removal("ui.prev_view"))
	resolver.push(items, resolver.removal("ui.help"))
	help.remove(GROUP, items, { buffer = buf })
end

return M
