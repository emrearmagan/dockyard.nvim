--- @class LogParser
--- @field name string Display name
--- @field type "docker"|"file" Log source type
--- @field path? string File path for "file" type log parsers
--- @field format? string Log format for "file" type log parsers (e.g., "json", "plain")
--- @field parser? function Main parser function
--- @field detail_parser? function Detail popup parser function

--- @class ContainerLogConfig
--- @field [1] LogParser Log parser configuration

--- @class LogLensConfig
--- @field max_lines number Maximum number of log lines to display
--- @field containers table<string, ContainerLogConfig> Per-container configs

--- @class DisplayConfig
--- @field views string[] Order of tabs

--- @class DockyardConfig
--- @field display DisplayConfig Display settings
--- @field loglens LogLensConfig Log lens settings

local M = {}

---@type DockyardConfig
M.options = {
	display = {
		views = { "containers", "images", "networks" },
	},
	loglens = {
		max_lines = 2000,
		containers = {},
	},
}

---@param opts? DockyardConfig
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M
