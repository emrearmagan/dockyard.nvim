local M = {}

function M.setup(opts)
	vim.notify("Dockyard setup is not implemented yet")
	local config = require("dockyard.config")
	config.setup(opts)

	vim.notify("Dockyard setup is complete" .. config.options.loglens.max_lines)
end

return M
