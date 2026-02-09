local docker = require("dockyard.docker")
local containers = require("dockyard.containers")
local images = require("dockyard.images")
local networks = require("dockyard.networks")
local ui = require("dockyard.ui")
local config = require("dockyard.config")
local state = require("dockyard.ui.state")

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
end

local function stop_timer()
	if state.refresh_timer then
		state.refresh_timer:stop()
		if not state.refresh_timer:is_closing() then
			state.refresh_timer:close()
		end
		state.refresh_timer = nil
	end
end

local function start_timer()
	stop_timer()
	local interval = config.options.display.refresh_interval
	if interval and interval > 0 then
		state.refresh_timer = vim.loop.new_timer()
		state.refresh_timer:start(interval, interval, vim.schedule_wrap(function()
			if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
				M.refresh({ silent = true })
				ui.render(state.mode)
			else
				stop_timer()
			end
		end))
	end
end

function M.setup(opts)
	config.setup(opts)
	M._opts = config.options

	if M._opts.notifier then
		containers.set_notifier(M._opts.notifier)
	end

	ensure_commands()

	if M._opts.auto_refresh ~= false then
		containers.refresh({ silent = true })
		images.refresh({ silent = true })
		networks.refresh({ silent = true })
	end

	-- Initialize current_view from order if containers not in order
	local order = M._opts.display.view_order
	if order and #order > 0 then
		state.current_view = order[1]
	end
end

function M.refresh(opts)
	containers.refresh(opts)
	images.refresh(opts)
	networks.refresh(opts)
end

function M.open()
	M.refresh({ silent = true })
	local win = ui.open()
	start_timer()
	return win
end

function M.open_full()
	M.refresh({ silent = true })
	local win = ui.open_full()
	start_timer()
	return win
end

function M.close()
	stop_timer()
	return ui.close()
end

return M

