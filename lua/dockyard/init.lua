local M = {}

function M.setup(opts)
	local config = require("dockyard.config")
	config.setup(opts)

	local docker = require("dockyard.docker")
	docker.list_networks(function(result)
		if result.ok then
			print(vim.inspect(result.data))
		else
			vim.notify("Error listing containers:\n" .. result.error, vim.log.levels.ERROR)
		end
	end)
end

function M.open()
	vim.notify("Opening Dockyard UI (not yet implemented)")
end

return M
