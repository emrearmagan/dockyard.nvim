--- @alias LogSourceType "docker"|"file"
--- "docker" = fetch from `docker logs` command (stdout/stderr)
--- "file"   = read from a file inside the container

--- @alias LogParserType "json"|"text"
--- "auto" = detect JSON automatically (line starts with { or [)
--- "json" = always parse as JSON
--- "text" = treat as plain text, no parsing

--- Maps your JSON keys to standard field names.
--- Different frameworks use different names:
---   Your app:    { level: "info", message: "...", timestamp: "..." }
---   Pino/Bunyan: { level: 30, msg: "...", time: 1234567890 }
---   Zap:         { level: "info", msg: "...", ts: 1234567890 }
---
--- @class LogFieldMapping
--- @field level? string     JSON key for log level (default: "level")
--- @field message? string   JSON key for message (default: "message")
--- @field timestamp? string JSON key for timestamp (default: "timestamp")

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
--- @field type LogSourceType                 Where to get logs ("docker" or "file")
--- @field path? string                       File path (required when type="file")
--- @field parser LogParserType|fun(line: string): table<string, any>|nil
--- @field fields? LogFieldMapping            JSON field mappings (for json parser)
--- @field format? fun(entry: table): table<string, any>   User function to format the display row
--- @field highlights? LogHighlightRule[]     Highlight rules for this source

--- @class ContainerLogConfig
--- @field sources? LogSource[]   Log sources for this container
--- @field max_lines? number      Override global max_lines
--- @field follow? boolean        Override global follow
--- @field tail? number           Override global tail

--- @class LogLensConfig
--- @field max_lines? number                             Max lines in buffer (default: 2000)
--- @field follow? boolean                               Auto-scroll to new logs (default: true)
--- @field tail? number                                  Lines to fetch initially (default: 100)
--- @field containers? table<string, ContainerLogConfig> Per-container configurations

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
		max_lines = 2000,
		follow = true,
		tail = 100,
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
