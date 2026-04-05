local M = {}

local data_state = require("dockyard.state")
local renderer = require("dockyard.ui.views.networks.renderer")
local state = require("dockyard.ui.views.networks.state")
local ui_state = require("dockyard.ui.state")

local function render()
	if ui_state.current_view ~= "networks" then
		return
	end
	if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
		renderer.render()
	end
end

---@param on_done fun()|nil
---@param opts { force_update?: boolean }|nil
function M.update(on_done, opts)
	local items = data_state.networks.get_items()
	local has_data = type(items) == "table" and #items > 0
	if (opts and opts.force_update) or not has_data then
		data_state.networks.refresh({
			silent = false,
			on_success = function()
				render()
				if on_done then
					on_done()
				end
			end,
			on_error = function()
				render()
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

function M.toggle(node)
	if not node or node.kind ~= "network" then
		return
	end
	state.toggle(node.key)
end

---@param node table|nil
function M.open_details(node)
	if not node then
		return
	end
	if node.kind == "network" then
		require("dockyard.ui.popups.network").open(node)
		return
	end
	if node.kind == "container" then
		require("dockyard.ui.popups.container").open(node.item or node)
	end
end

function M.reset()
	state.reset()
end

return M
