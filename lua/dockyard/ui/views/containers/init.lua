local M = {}

local keymaps = require("dockyard.ui.views.containers.keymaps")
local controller = require("dockyard.ui.views.containers.controller")

---@param buf number
---@param notify fun(msg:string,level?:integer)
function M.setup(buf, notify)
	keymaps.setup(buf, notify, {
		on_done = function(_, ok)
			if ok then
				M.update(nil, { force_update = true })
			end
		end,
	})
end

---@param on_done fun()|nil
---@param opts { force_update?: boolean }|nil
function M.update(on_done, opts)
	if opts and opts.force_update then
		return controller.update(on_done, { force_update = true })
	end

	controller.update(on_done)
end

---@param buf number
function M.teardown(buf)
	keymaps.teardown(buf)
end

return M
