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
--- A log source defines where to get logs and how to display them.
--- A container can have multiple sources (docker output, various log files).
--- Omitting `path` streams docker stdout/stderr (equivalent to `docker logs -f`).
--- For path-less sources, `parser` and `format` default to plain-text if not set.
---
--- @class LogSource
--- @field name? string                       Display name (auto-generated if omitted)
--- @field path? string                       File path inside the container; omit to stream docker logs
--- @field parser? LogParserType              How to parse logs ("json" or "text"); defaults to "text" when path is absent
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
--- @field default_highlights? LogHighlightRule[]        Fallback highlights for all containers (overrides built-in defaults)

--- @alias DockyardView "containers"|"compose"|"images"|"networks"|"volumes"

--- @class DisplayConfig
--- @field views? DockyardView[] Ordered list of views shown in the navbar

--- @class DockyardConfig
--- @field display? DisplayConfig Display settings
--- @field loglens? LogLensConfig LogLens settings
--- @field keymaps? DockyardKeymapsConfig Keybindings (see core/keymaps.lua for type)

local M = {}

---@type DockyardConfig
M.options = {
	display = {
		views = { "containers", "images", "networks", "volumes" },
	},
	loglens = {
		containers = {},
	},
	keymaps = {
		ui = {
			help = "g?",
			close = "q",
			refresh = "R",
			next_view = { "<Tab>", "]" },
			prev_view = { "<S-Tab>", "[" },
			toggle_node = "<CR>",
			open_details = "K",
			open_panel = "p",
		},
		containers = {
			toggle_start_stop = "s",
			stop = "x",
			restart = "r",
			remove = "d",
			open_terminal = "T",
			open_logs = "L",
			open_files = "f",
		},
		images = {
			remove = "d",
			prune = "P",
		},
		networks = {
			remove = "d",
		},
		volumes = {
			remove = "d",
		},
		loglens = {
			close = "q",
			toggle_follow = "f",
			toggle_raw = "r",
			filter = "/",
			clear_filter = "c",
			next_source = "<Tab>",
			prev_source = "<S-Tab>",
			open_detail = { "<CR>", "K" },
			help = "g?",
		},
	},
}

local function create_commands()
	pcall(vim.api.nvim_del_user_command, "Dockyard")
	pcall(vim.api.nvim_del_user_command, "DockyardFloat")
	pcall(vim.api.nvim_del_user_command, "DockyardFull")
	pcall(vim.api.nvim_del_user_command, "DockyardBuild")
	pcall(vim.api.nvim_del_user_command, "DockyardRun")
	pcall(vim.api.nvim_del_user_command, "DockyardFiles")

	vim.api.nvim_create_user_command("Dockyard", function()
		require("dockyard.ui").open_full()
	end, { desc = "Open Dockyard UI" })

	vim.api.nvim_create_user_command("DockyardFloat", function()
		require("dockyard.ui").open()
	end, { desc = "Open Dockyard Floating UI" })

	vim.api.nvim_create_user_command("DockyardBuild", function()
		require("dockyard.commands").build()
	end, { desc = "Build Docker image from current Dockerfile" })

	vim.api.nvim_create_user_command("DockyardRun", function(cmd_opts)
		if cmd_opts.range == 2 then
			require("dockyard.commands").run_visual(cmd_opts.line1, cmd_opts.line2)
		else
			require("dockyard.commands").run_all()
		end
	end, { desc = "Run Docker Compose services", range = true })

	vim.api.nvim_create_user_command("DockyardFiles", function(cmd_opts)
		local container = cmd_opts.fargs[1]
		local path = cmd_opts.fargs[2] or "/"
		if not container or container == "" then
			vim.notify("DockyardFiles: container required", vim.log.levels.ERROR)
			return
		end
		require("dockyard.files").open(container, path)
	end, {
		desc = "Browse a container's filesystem",
		nargs = "+",
		complete = function(arg_lead)
			local out = vim.fn.systemlist({ "docker", "ps", "--format", "{{.Names}}" })
			local matches = {}
			for _, name in ipairs(out) do
				if name:find(arg_lead, 1, true) == 1 then
					table.insert(matches, name)
				end
			end
			return matches
		end,
	})
end

---@param opts? DockyardConfig
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
	create_commands()
end

return M
