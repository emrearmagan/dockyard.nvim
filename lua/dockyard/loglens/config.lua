local dockyard_config = require("dockyard.config")

local M = {}

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

---@param container_name string
---@return ContainerLogConfig|nil
function M.get_container_config(container_name)
	local opts = dockyard_config.options.loglens or {}
	local containers = opts.containers or {}
	local cfg = containers[container_name]
	if cfg then
		return cfg
	end

	return {
		sources = {
			{
				parser = "text",
				format = function(entry)
					if entry == "" then
						return nil
					end

					return {
						logs = entry,
					}
				end,
			},
		},
	}
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
		highlights = cfg.highlights or (resolved_sources[1] and resolved_sources[1].highlights or nil),
	},
		nil
end

return M
