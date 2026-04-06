local loglens_config = require("dockyard.loglens.config")
local parser_factory = require("dockyard.loglens.parsers")
local stream = require("dockyard.loglens.parsers.stream")

local M = {}

---@class LogStreamInstance
---@field entries LogLensEntry[]
---@field active_source table|nil
---@field max_lines number
---@field container Container|nil
---@field container_name string|nil
---@field _job_ids number[]
---@field _parser_sessions LogLensParserSession[]
---@field _on_entries fun(entries: LogLensEntry[])|nil
---@field start fun(self: LogStreamInstance, container: Container): boolean, string|nil
---@field stop fun(self: LogStreamInstance)
---@field is_streaming fun(self: LogStreamInstance): boolean

---@param opts? { on_entries?: fun(entries: LogLensEntry[]), max_lines?: number }
---@return LogStreamInstance
function M.create(opts)
	opts = opts or {}

	---@type LogStreamInstance
	local instance = {
		entries = {},
		active_source = nil,
		max_lines = 1000,
		container = nil,
		container_name = nil,
		_stream_handles = {},
		_parser_sessions = {},
		_on_entries = opts.on_entries,
	}

	local function trim_entries()
		while #instance.entries > instance.max_lines do
			table.remove(instance.entries, 1)
		end
	end

	local function append_rows(rows)
		for _, row in ipairs(rows or {}) do
			table.insert(instance.entries, row)
		end
		trim_entries()
		if instance._on_entries then
			instance._on_entries(instance.entries)
		end
	end

	local function flush_sessions()
		for _, session in ipairs(instance._parser_sessions) do
			local rows = session:flush()
			if #rows > 0 then
				append_rows(rows)
			end
		end
	end

	local function stop_jobs()
		for _, handle in ipairs(instance._stream_handles) do
			handle.stop()
		end
		instance._stream_handles = {}
	end

	---@param container Container
	---@return boolean success
	---@return string|nil error
	function instance:start(container)
		self:stop()

		local runtime, err = loglens_config.resolve_runtime(container)
		if not runtime then
			return false, err
		end

		local parser_sessions = {}
		for _, source in ipairs(runtime.sources or {}) do
			local session, parser_err = parser_factory.create_session(source)
			if not session then
				return false, parser_err
			end
			table.insert(parser_sessions, session)
		end

		self.container = container
		self.container_name = loglens_config.normalize_container_name(container.name)
		self.entries = {}
		self.active_source = {
			_order = runtime._order,
			highlights = runtime.highlights,
		}
		self.max_lines = opts.max_lines or runtime.max_lines
		self._parser_sessions = parser_sessions
		self._stream_handles = {}

		for i, source in ipairs(runtime.sources or {}) do
			local session = self._parser_sessions[i]
			if session then
				local handle = stream.start(container, source, source.tails, function(chunk)
					local rows = session:push(chunk)
					if #rows > 0 then
						append_rows(rows)
					end
				end, function()
					local tail_rows = session:flush()
					if #tail_rows > 0 then
						append_rows(tail_rows)
					end
				end)

				if handle then
					table.insert(self._stream_handles, handle)
				end
			end
		end

		return true, nil
	end

	function instance:stop()
		flush_sessions()
		stop_jobs()
	end

	---@return boolean
	function instance:is_streaming()
		return #self._stream_handles > 0
	end

	return instance
end

return M
