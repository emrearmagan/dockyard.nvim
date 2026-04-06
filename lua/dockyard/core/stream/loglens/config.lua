local dockyard_config = require("dockyard.config")

local M = {}

--- Default highlight rules applied when no container- or source-level highlights are configured.
---@type LogHighlightRule[]
local DEFAULT_HIGHLIGHTS = {
	-- Error / critical severity (red)
	{ pattern = "%f[%a]FATAL%f[%A]", group = "DockyardStopped" },
	{ pattern = "%f[%a]CRITICAL%f[%A]", group = "DockyardStopped" },
	{ pattern = "%f[%a]EMERG%f[%A]", group = "DockyardStopped" },
	{ pattern = "%f[%a]ALERT%f[%A]", group = "DockyardStopped" },
	{ pattern = "%f[%a]ERROR%f[%A]", group = "DockyardStopped" },
	{ pattern = "%f[%a]ERR%f[%A]", group = "DockyardStopped" },

	-- Warning severity (yellow)
	{ pattern = "%f[%a]WARNING%f[%A]", group = "DockyardPaused" },
	{ pattern = "%f[%a]WARN%f[%A]", group = "DockyardPaused" },

	-- Info / notice severity (blue)
	{ pattern = "%f[%a]INFO%f[%A]", group = "DockyardName" },
	{ pattern = "%f[%a]NOTICE%f[%A]", group = "DockyardName" },
	{ pattern = "%f[%a]LOG%f[%A]", group = "DockyardName" },

	-- Debug / trace severity (muted)
	{ pattern = "%f[%a]DEBUG%f[%A]", group = "DockyardMuted" },
	{ pattern = "%f[%a]TRACE%f[%A]", group = "DockyardMuted" },
	{ pattern = "%f[%a]VERBOSE%f[%A]", group = "DockyardMuted" },

	-- ISO 8601 timestamps: 2026-04-06T17:23:46 or 2026-04-06 17:23:46
	{ pattern = "%d%d%d%d%-%d%d%-%d%d[T ]%d%d:%d%d:%d%d", group = "DockyardMuted" },
	{ pattern = "%d%d:%d%d:%d%d", group = "DockyardMuted" },

	-- Quoted strings (e.g. HTTP request lines: "GET /path HTTP/1.1")
	{ pattern = '"[^"]*"', group = "DockyardImage" },

	-- IPv4 addresses (with or without port)
	{ pattern = "%d+%.%d+%.%d+%.%d+", group = "DockyardPorts" },

	-- HTTP status codes (whitespace-bounded to avoid matching timestamps/ports)
	{ pattern = "%s2%d%d%s", group = "DockyardRunning" }, -- 2xx success
	{ pattern = "%s3%d%d%s", group = "DockyardName" }, -- 3xx redirect
	{ pattern = "%s4%d%d%s", group = "DockyardPending" }, -- 4xx client error
	{ pattern = "%s5%d%d%s", group = "DockyardStopped" }, -- 5xx server error
}

---@param value any
---@param fallback number
---@return number
local function positive_integer_or(value, fallback)
	if type(value) ~= "number" then
		return fallback
	end

	local n = math.floor(value)
	if n < 1 then
		return fallback
	end

	return n
end

---@class LogLensRuntime
---@field sources LogSource[]
---@field max_lines number
---@field _order string[]|nil
---@field highlights LogHighlightRule[]|nil

---@param name string|nil
---@return string
function M.normalize_container_name(name)
	return (tostring(name or ""):gsub("^/", ""))
end

---@type LogSource
local DEFAULT_DOCKER_SOURCE = {
	parser = "text",
	format = function(entry)
		if entry == "" then
			return nil
		end
		return { logs = entry }
	end,
}

---@param container_name string
---@return ContainerLogConfig|nil
function M.get_container_config(container_name)
	local opts = dockyard_config.options.loglens or {}
	local containers = opts.containers or {}
	local cfg = containers[container_name]

	if cfg then
		if not cfg.sources or #cfg.sources == 0 then
			cfg = vim.tbl_extend("keep", { sources = { DEFAULT_DOCKER_SOURCE } }, cfg)
		end
		return cfg
	end

	return { sources = { DEFAULT_DOCKER_SOURCE } }
end

---@param source LogSource
---@return boolean
---@return string|nil
function M.validate_source(source)
	if not source then
		return false, "Missing source config"
	end
	if source.parser ~= "text" and source.parser ~= "json" then
		return false, "source.parser must be 'text' or 'json'"
	end
	if type(source.format) ~= "function" then
		return false, "source.format(entry) or container.format(entry) is required"
	end
	return true, nil
end

---@param cfg ContainerLogConfig
---@param source LogSource
---@return LogSource
local function resolve_source_config(cfg, source)
	local resolved = vim.tbl_deep_extend("force", {}, source)

	-- no path = docker logs
	if not resolved.path or resolved.path == "" then
		if resolved.parser == nil then
			resolved.parser = "text"
		end
		if resolved.format == nil then
			resolved.format = function(entry)
				if entry == "" then
					return nil
				end
				return { logs = entry }
			end
		end
	end

	if resolved.format == nil then
		resolved.format = cfg.format
	end
	if resolved._order == nil then
		resolved._order = cfg._order
	end
	if resolved.highlights == nil then
		resolved.highlights = cfg.highlights
	end
	if resolved.tails == nil then
		resolved.tails = cfg.tails
	end
	if resolved.max_lines == nil then
		resolved.max_lines = cfg.max_lines
	end

	resolved.tails = positive_integer_or(resolved.tails, 100)
	resolved.max_lines = positive_integer_or(resolved.max_lines, 1000)

	return resolved
end

---@param container Container
---@return LogLensRuntime|nil
---@return string|nil
function M.resolve_runtime(container)
	local name = M.normalize_container_name(container.name)
	local cfg = M.get_container_config(name)
	if not (cfg and cfg.sources and #cfg.sources > 0) then
		return nil, string.format("No sources configured for container '%s'", name)
	end

	local resolved_sources = {}
	for _, source in ipairs(cfg.sources) do
		local resolved = resolve_source_config(cfg, source)
		local ok, err = M.validate_source(resolved)
		if not ok then
			return nil, err
		end
		table.insert(resolved_sources, resolved)
	end

	local max_lines = cfg.max_lines
	if max_lines == nil then
		max_lines = resolved_sources[1] and resolved_sources[1].max_lines or nil
	end

	return {
		sources = resolved_sources,
		max_lines = positive_integer_or(max_lines, 1000),
		_order = cfg._order or (resolved_sources[1] and resolved_sources[1]._order or nil),
		highlights = cfg.highlights or (resolved_sources[1] and resolved_sources[1].highlights) or (
			dockyard_config.options.loglens or {}
		).default_highlights or DEFAULT_HIGHLIGHTS,
	},
		nil
end

return M
