local M = {}

local data_state = require("dockyard.state")
local renderer = require("dockyard.ui.views.containers.renderer")
local ui_state = require("dockyard.ui.state")
local navigation = require("dockyard.ui.navigation")

---@param opts { focus_first?: boolean }|nil
local function render(opts)
	if ui_state.current_view ~= "containers" then
		return
	end
	if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
		renderer.render()

		if opts and opts.focus_first == true then
			navigation.first()
		end
	end
end

---@param on_done fun()|nil
---@param opts { force_update?: boolean }|nil
function M.update(on_done, opts)
	local items = data_state.containers.get_items()
	local has_data = type(items) == "table" and #items > 0
	if (opts and opts.force_update) or not has_data then
		data_state.containers.refresh({
			silent = false,
			on_success = function()
				render({ focus_first = true })
				if on_done then
					on_done()
				end
			end,
			on_error = function()
				render({ focus_first = true })
				if on_done then
					on_done()
				end
			end,
		})
		return
	end

	render()
	if on_done then
		on_done()
	end
end

---@param item Container
function M.open_terminal(item)
	require("dockyard.ui.views.terminal").open(item.id, "sh", {
		mode = ui_state.mode,
		win = ui_state.win_id,
	})
end

---@param item Container
function M.open_logs(item)
	require("dockyard.loglens").open(item)
end

---@param item Container
function M.open_details(item)
	require("dockyard.ui.popups.container").open(item)
end

function M.on_teardown() end

return M
