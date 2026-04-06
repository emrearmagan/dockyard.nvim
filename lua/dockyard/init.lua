local M = {}

---@param opts? DockyardConfig
function M.setup(opts)
	local config = require("dockyard.config")
	config.setup(opts)

	require("dockyard.ui.highlights").setup()
end

function M.refresh()
	require("dockyard.ui").refresh()
end

return M
