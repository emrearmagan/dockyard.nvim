local docker = require("dockyard.docker")
local containers = require("dockyard.containers")
local images = require("dockyard.images")
local networks = require("dockyard.networks")
local ui = require("dockyard.ui")

local M = {}

local commands_ready = false

local function ensure_commands()
	if commands_ready then
		return
	end
	commands_ready = true

	vim.api.nvim_create_user_command("Dockyard", function()
		require("dockyard").open()
	end, { desc = "Open Dockyard UI" })

	vim.api.nvim_create_user_command("DockyardFull", function()
		require("dockyard").open_full()
	end, { desc = "Open Dockyard in a new tab" })

	vim.api.nvim_create_user_command("DockyardRefresh", function()
		require("dockyard").refresh()
	end, { desc = "Refresh Dockyard cache" })
end

function M.setup(opts)
	M._opts = opts or {}

	if M._opts.notifier then
		containers.set_notifier(M._opts.notifier)
	end

	ensure_commands()

	if M._opts.auto_refresh ~= false then
		containers.refresh({ silent = true })
		images.refresh({ silent = true })
		networks.refresh({ silent = true })
	end
end

M.list_containers = docker.list_containers
M.list_images = docker.list_images
M.list_networks = docker.list_networks
M.containers = containers
M.images = images
M.networks = networks

function M.refresh(opts)
	containers.refresh(opts)
	images.refresh(opts)
	networks.refresh(opts)
end

function M.open()
	containers.refresh({ silent = true })
	images.refresh({ silent = true })
	networks.refresh({ silent = true })
	return ui.open()
end

function M.open_full()
	containers.refresh({ silent = true })
	images.refresh({ silent = true })
	networks.refresh({ silent = true })
	if ui.open_full then
		return ui.open_full()
	end
	return ui.open()
end

return M
