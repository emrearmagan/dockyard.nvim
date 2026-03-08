local dockyard_config = require("dockyard.config")

local M = {}

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
	return containers[container_name]
end

---@param source LogSource
---@return boolean
---@return string|nil
function M.validate_source(source)
	if not source then
		return false, "Missing source config"
	end
	if source.type ~= "docker" and source.type ~= "file" then
		return false, "source.type must be 'docker' or 'file'"
	end
	if source.type == "file" and not source.path then
		return false, "file source needs source.path"
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
		max_lines = 2000,
		tail = 100,
	}, nil
end

return M
