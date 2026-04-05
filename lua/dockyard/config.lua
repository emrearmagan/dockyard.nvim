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
--- @field _order? string[]                   Optional per-source column key order override
--- @field max_lines? number                  Optional per-source max rows override
--- @field tails? number                      Number of lines to tail on initial load (default: 100)
--- @field format? fun(entry: any, ctx: table): table<string, any> Optional per-source formatter override
--- @field highlights? LogHighlightRule[]     Optional per-source highlight override

--- @class ContainerLogConfig
--- @field sources? LogSource[]                   Log sources for this container
--- @field _order? string[]                       Default column order for all sources
--- @field max_lines? number                      Max rows kept in memory (default: 1000)
--- @field tails? number                          Default initial tail lines for each source (default: 100)
--- @field format? fun(entry: any, ctx: table): table<string, any> Default formatter for all sources
--- @field highlights? LogHighlightRule[]         Default highlight rules for all sources

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
		views = { "containers", "images", "networks", "volumes" },
	},
	loglens = {
		containers = {},
	},
}

local function create_commands()
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
