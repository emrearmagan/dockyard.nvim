local M = {}

local docker = require("dockyard.core.docker")

---@class StatsSnapshot
---@field cpu number
---@field mem number

---@class StatsStreamInstance
---@field container_id string|nil
---@field history StatsSnapshot[]
---@field latest ContainerStats|nil
---@field max_history number
---@field _stop_fn fun()|nil
---@field start fun(self: StatsStreamInstance, container_id: string)
---@field stop fun(self: StatsStreamInstance)
---@field cpu_data fun(self: StatsStreamInstance): number[]
---@field mem_data fun(self: StatsStreamInstance): number[]
---@field cpu_avg fun(self: StatsStreamInstance): number
---@field cpu_peak fun(self: StatsStreamInstance): number
---@field mem_peak fun(self: StatsStreamInstance): number

---@param opts? { on_update?: fun(), max_history?: number }
---@return StatsStreamInstance
function M.create(opts)
	opts = opts or {}

	---@type StatsStreamInstance
	local instance = {
		container_id = nil,
		history = {},
		latest = nil,
		max_history = opts.max_history or 60,
		_stop_fn = nil,
	}

	---@param container_id string
	function instance:start(container_id)
		self:stop()
		self.container_id = container_id
		self.history = {}
		self.latest = nil

		self._stop_fn = docker.stream_stats(container_id, function(data)
			self.latest = data

			local cpu = tonumber((data.cpu_perc or ""):match("([%d%.]+)")) or 0
			local mem = tonumber((data.mem_perc or ""):match("([%d%.]+)")) or 0

			table.insert(self.history, { cpu = cpu, mem = mem })
			while #self.history > self.max_history do
				table.remove(self.history, 1)
			end

			if opts.on_update then
				opts.on_update()
			end
		end)
	end

	function instance:stop()
		if self._stop_fn then
			self._stop_fn()
			self._stop_fn = nil
		end
		self.container_id = nil
	end

	---@return number[]
	function instance:cpu_data()
		local out = {}
		for _, h in ipairs(self.history) do
			table.insert(out, h.cpu)
		end
		return out
	end

	---@return number[]
	function instance:mem_data()
		local out = {}
		for _, h in ipairs(self.history) do
			table.insert(out, h.mem)
		end
		return out
	end

	---@return number
	function instance:cpu_avg()
		if #self.history == 0 then return 0 end
		local sum = 0
		for _, h in ipairs(self.history) do sum = sum + h.cpu end
		return sum / #self.history
	end

	---@return number
	function instance:cpu_peak()
		local peak = 0
		for _, h in ipairs(self.history) do
			if h.cpu > peak then peak = h.cpu end
		end
		return peak
	end

	---@return number
	function instance:mem_peak()
		local peak = 0
		for _, h in ipairs(self.history) do
			if h.mem > peak then peak = h.mem end
		end
		return peak
	end

	return instance
end

return M
