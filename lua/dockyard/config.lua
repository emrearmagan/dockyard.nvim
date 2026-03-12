--- @alias LogParserType "json"|"text"
--- "json" = always parse as JSON
--- "text" = treat as plain text, no parsing

--- A single highlight rule. Matches a Lua pattern and applies a color.
--- Use EITHER 'group' (Neovim highlight group) OR 'color' (hex), not both.
---
--- @class LogHighlightRule
--- @field pattern string    Lua pattern to match (e.g., "%[ERROR%]", "%d+%.%d+%.%d+%.%d+")
--- @field group? string     Neovim highlight group (e.g., "DiagnosticError", "Comment")
--- @field color? string     Hex color (e.g., "#ff5555", "#50fa7b")
---
--- Examples:
---   { pattern = "%[ERROR%]", group = "DiagnosticError" }  -- Use built-in group
---   { pattern = "%[CRITICAL%]", color = "#ff0000" }       -- Use custom hex color
---   { pattern = "%d%d:%d%d:%d%d", group = "Comment" }     -- Timestamps gray

--- A log source defines where to get logs and how to display them.
--- A container can have multiple sources (docker output, various log files).
---
--- @class LogSource
--- @field name? string                       Display name (auto-generated if omitted)
--- @field path? string                       If set, logs are read from this file in container
--- @field parser LogParserType               How to parse logs ("json" or "text")
--- @field _order? string[]                   Optional column key order (e.g. {"time","level","message"})
--- @field max_lines? number                  Max rows kept in memory per LogLens session (default: 1000)
--- @field tails? number                      Number of lines to tail on initial load (default: 100)
--- @field format? fun(entry: table): table<string, any>   User function to format the display row
--- @field highlights? LogHighlightRule[]     Highlight rules for this source

--- @class ContainerLogConfig
--- @field sources? LogSource[]   Log sources for this container

--- @class LogLensConfig
--- @field containers? table<string, ContainerLogConfig> Per-container configurations

-- TODO: Currently not used
--- @class DisplayConfig
--- @field views string[] Order of tabs

--- @class DockyardConfig
--- @field display DisplayConfig Display settings
--- @field loglens LogLensConfig LogLens settings

local M = {}

---@type DockyardConfig
M.options = {
	display = {
		views = { "containers", "images", "networks" },
	},
	loglens = {
		containers = {},
	},
}

local function create_commands()
	-- Ensure we replace any stale command handlers from previous reloads.
	pcall(vim.api.nvim_del_user_command, "Dockyard")
	pcall(vim.api.nvim_del_user_command, "DockyardFloat")
	pcall(vim.api.nvim_del_user_command, "DockyardFull")

	vim.api.nvim_create_user_command("Dockyard", function()
		require("dockyard.ui").open_full()
	end, { desc = "Open Dockyard UI" })

	vim.api.nvim_create_user_command("DockyardFloat", function()
		require("dockyard.ui").open()
	end, { desc = "Open Dockyard Floating UI" })
end

---@param opts? DockyardConfig
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
	create_commands()
end

return M
