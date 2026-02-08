local M = {}

local defaults = {
	display = {
		refresh_interval = 5000, -- 0 to disable
		view_order = { "containers", "images", "networks" },
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
