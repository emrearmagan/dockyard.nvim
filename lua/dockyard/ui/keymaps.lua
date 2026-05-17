local M = {}

local navigation = require("dockyard.ui.navigation")
local help = require("dockyard.ui.popups.help")

local GROUP = "General"
local INDEX = 10

---@param buf number
---@param handlers { close: fun(), refresh: fun(), next_view: fun(), prev_view: fun(), open_help?: fun() }
function M.register_global(buf, handlers)
	local items = {
		{
			key = "q",
			desc = "Close Dockyard",
			callback = function()
				handlers.close()
			end,
			index = 1,
		},
		{
			key = "R",
			desc = "Refresh current view",
			callback = function()
				handlers.refresh()
			end,
			index = 2,
		},
		{
			key = "<Tab>",
			desc = "Next tab",
			callback = function()
				handlers.next_view()
			end,
			index = 3,
		},
		{
			key = "<S-Tab>",
			desc = "Previous tab",
			callback = function()
				handlers.prev_view()
			end,
			index = 4,
		},
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
		{
			key = "g?",
			desc = "Toggle this help popup",
			callback = function()
				if handlers.open_help then
					handlers.open_help()
				else
					help.toggle({ buffer = buf })
				end
			end,
			index = 99,
		},
	}

	help.register(GROUP, items, { buffer = buf, index = INDEX })
end

function M.unregister_global(buf)
	local items = {
		{ key = "q" },
		{ key = "R" },
		{ key = "<Tab>" },
		{ key = "<S-Tab>" },
		{ key = "j" },
		{ key = "k" },
		{ key = "g?" },
	}
	help.remove(GROUP, items, { buffer = buf })
end

return M
