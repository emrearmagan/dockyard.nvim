local M = {}

local help = require("dockyard.ui.popups.help")
local resolver = require("dockyard.core.keymaps")

local GROUP = "LogLens"
local INDEX = 10

---@param buf number
---@param state LogLensState
---@param handlers { close: fun(), refresh: fun(), open_detail: fun() }
function M.attach(buf, state, handlers)
	local items = {}

	resolver.push(
		items,
		resolver.item("loglens.close", {
			desc = "Close LogLens",
			callback = function()
				handlers.close()
			end,
			index = 1,
		})
	)
	resolver.push(
		items,
		resolver.item("loglens.toggle_follow", {
			desc = "Toggle follow mode",
			callback = function()
				state.follow = not state.follow
				handlers.refresh()
			end,
			index = 2,
		})
	)
	resolver.push(
		items,
		resolver.item("loglens.toggle_raw", {
			desc = "Toggle raw output",
			callback = function()
				state.raw = not state.raw
				handlers.refresh()
			end,
			index = 3,
		})
	)
	resolver.push(
		items,
		resolver.item("loglens.filter", {
			desc = "Filter logs",
			callback = function()
				vim.ui.input({
					prompt = "Filter logs: ",
					default = state.filter or "",
				}, function(input)
					if input == nil then
						return
					end

					if input == "" then
						state.filter = nil
					else
						state.filter = input
					end

					handlers.refresh()
				end)
			end,
			index = 4,
		})
	)
	resolver.push(
		items,
		resolver.item("loglens.clear_filter", {
			desc = "Clear filter",
			callback = function()
				if state.filter ~= nil then
					state.filter = nil
					handlers.refresh()
				end
			end,
			index = 5,
		})
	)
	resolver.push(
		items,
		resolver.item("loglens.open_detail", {
			desc = "Open log entry detail",
			callback = function()
				handlers.open_detail()
			end,
			index = 6,
		})
	)
	resolver.push(
		items,
		resolver.item("loglens.help", {
			desc = "Toggle this help popup",
			callback = function()
				help.toggle({ buffer = buf })
			end,
			index = 99,
		})
	)

	help.register(GROUP, items, { buffer = buf, index = INDEX })

	local group = vim.api.nvim_create_augroup("DockyardLogLensFollow" .. tostring(buf), { clear = true })
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = buf,
		callback = function()
			if not state.follow then
				return
			end
			local line = vim.api.nvim_win_get_cursor(0)[1]
			local last = vim.api.nvim_buf_line_count(buf)
			-- Only disable follow when user moved away from bottom.
			if line < last then
				state.follow = false
				handlers.refresh()
			end
		end,
	})
end

return M
