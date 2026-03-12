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
---@field source LogSource
---@field max_lines number
---@field tail number

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
				type = "docker",
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
		return false, "source.format(entry) is required"
	end
	return true, nil
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

	local source = cfg.sources[1]
	local ok, err = M.validate_source(source)
	if not ok then
		return nil, err
	end

	return {
		source = source,
		max_lines = positive_integer_or(source.max_lines, 1000),
		tail = positive_integer_or(source.tails, 100),
	},
		nil
end

return M
