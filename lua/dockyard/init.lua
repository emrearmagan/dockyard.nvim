local docker = require("dockyard.docker")

local M = {}

function M.setup(opts)
	vim.notify("Dockyard.nvim scaffold loaded", vim.log.levels.INFO)
	M._opts = opts or {}
end

M.list_containers = docker.list_containers

return M
