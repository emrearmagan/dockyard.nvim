local M = {}

local function setup_keymaps()
	vim.api.nvim_create_user_command("Dockyard", function()
		local ui = require("dockyard.ui")
		if ui.is_open() then
			ui.close()
		else
			ui.open()
		end
	end, { desc = "Toggle Dockyard UI" })

	vim.api.nvim_create_user_command("DockyardFull", function()
		local ui = require("dockyard.ui")
		if ui.is_open() then
			ui.close()
		else
			ui.open_full()
		end
	end, { desc = "Toggle Dockyard Fullscreen" })
end

function M.setup(opts)
	local config = require("dockyard.config")
	config.setup(opts)

	setup_keymaps()
end

return M
