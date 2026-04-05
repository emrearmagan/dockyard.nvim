local M = {}

local data_state = require("dockyard.state")
local renderer = require("dockyard.ui.views.volumes.renderer")
local ui_state = require("dockyard.ui.state")
local navigation = require("dockyard.ui.navigation")

---@param opts { focus_first?: boolean }|nil
local function render(opts)
	if ui_state.current_view ~= "volumes" then
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
	local items = data_state.volumes.get_items()
	local has_data = type(items) == "table" and #items > 0
	if (opts and opts.force_update) or not has_data then
		data_state.volumes.refresh({
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

---@param node { kind: string, item: Volume }|nil
function M.open_in_vim(node)
	if not node or node.kind ~= "volume" then
		return
	end

	local vol = node.item
	local path = vol and vol.mountpoint
	if not path or path == "" then
		vim.notify("Dockyard: volume has no mountpoint", vim.log.levels.WARN)
		return
	end

	-- Only open if the path actually exists on the host filesystem
	local stat = vim.loop.fs_stat(path)
	if not stat then
		vim.notify("Dockyard: mountpoint not accessible on host: " .. path, vim.log.levels.WARN)
		return
	end

	if stat.type == "directory" then
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	else
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end
end

return M
