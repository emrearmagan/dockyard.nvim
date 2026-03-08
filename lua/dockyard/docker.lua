local M = {}

local job = require("plenary.job")

---Normalize Docker status text into a stable semantic status key.
---@param raw string|nil
---@return "running"|"paused"|"restarting"|"dead"|"stopped"
function M.to_status(raw)
	raw = tostring(raw or ""):lower()
	if raw:find("up", 1, true) then
		return "running"
	end
	if raw:find("paused", 1, true) then
		return "paused"
	end
	if raw:find("restarting", 1, true) then
		return "restarting"
	end
	if raw:find("dead", 1, true) then
		return "dead"
	end
	return "stopped"
end

local function run_docker_command(args, callback)
	job:new({
		command = "docker",
		args = args,
		on_exit = function(j, return_val)
			vim.schedule(function()
				if return_val == 0 then
					local result = table.concat(j:result(), "\n")
					callback({ ok = true, data = result })
				else
					local stderr = table.concat(j:stderr_result(), "\n")
					callback({
						ok = false,
						error = stderr ~= "" and stderr or "Docker command failed",
					})
				end
			end)
		end,
	}):start()
end

--- @class Container
--- @field id string
--- @field name string
--- @field image string
--- @field command string
--- @field status string
--- @field ports string
--- @field networks string
--- @field created string
--- @field created_since string

--- @alias ContainerCallback fun(result: {ok: boolean, data: Container[], error?: string})
function M.list_containers(callback)
	local format = table.concat({
		"{",
		'  "id": {{json .ID}},',
		'  "name": {{json .Names}},',
		'  "image": {{json .Image}},',
		'  "command": {{json .Command}},',
		'  "status": {{json .Status}},',
		'  "ports": {{json .Ports}},',
		'  "networks": {{json .Networks}},',
		'  "created": {{json .CreatedAt}},',
		'  "created_since": {{json .RunningFor}}',
		"}",
	}, "")

	run_docker_command({ "ps", "-a", "--format", format }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		--- @type Container[]
		local containers = {}
		if result.data ~= "" then
			for line in result.data:gmatch("[^\r\n]+") do
				local ok, parsed = pcall(vim.json.decode, line)
				if ok and parsed then
					table.insert(containers, parsed)
				end
			end
		end

		callback({ ok = true, data = containers })
	end)
end

--- @class Image
--- @field id string
--- @field repository string
--- @field tag string
--- @field created string
--- @field created_since string
--- @field size string

--- @param callback fun(result: {ok: boolean, data: Image[], error?: string})
M.list_images = function(callback)
	local format = table.concat({
		"{",
		'  "id": {{json .ID}},',
		'  "repository": {{json .Repository}},',
		'  "tag": {{json .Tag}},',
		'  "created": {{json .CreatedAt}},',
		'  "created_since": {{json .CreatedSince}},',
		'  "size": {{json .Size}}',
		"}",
	}, "")

	run_docker_command({ "images", "--format", format }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		--- @type Image[]
		local images = {}
		if result.data ~= "" then
			for line in result.data:gmatch("[^\r\n]+") do
				local ok, parsed = pcall(vim.json.decode, line)
				if ok and parsed then
					table.insert(images, parsed)
				end
			end
		end

		callback({ ok = true, data = images })
	end)
end

--- @class Network
--- @field id string
--- @field name string
--- @field driver string
--- @field scope string
--- @field created string

--- @param callback fun(result: {ok: boolean, data: Network[], error?: string})
M.list_networks = function(callback)
	local format = table.concat({
		"{",
		'  "id": {{json .ID}},',
		'  "name": {{json .Name}},',
		'  "driver": {{json .Driver}},',
		'  "scope": {{json .Scope}},',
		'  "created": {{json .CreatedAt}}',
		"}",
	}, "")

	run_docker_command({ "network", "ls", "--format", format }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		--- @type Network[]
		local networks = {}
		if result.data ~= "" then
			for line in result.data:gmatch("[^\r\n]+") do
				local ok, parsed = pcall(vim.json.decode, line)
				if ok and parsed then
					table.insert(networks, parsed)
				end
			end
		end

		callback({ ok = true, data = networks })
	end)
end

--- @param container_id string
--- @param action "start"|"stop"|"restart"|"rm"
--- @param callback fun(result: {ok: boolean, error?: string})
M.container_action = function(container_id, action, callback)
	run_docker_command({ action, container_id }, function(result)
		if result.ok then
			callback({ ok = true })
		else
			callback({ ok = false, error = result.error })
		end
	end)
end

--- @param image_id string
--- @param action "rm"
--- @param callback fun(result: {ok: boolean, error?: string})
M.image_action = function(image_id, action, callback)
	run_docker_command({ "image", action, image_id }, function(result)
		if result.ok then
			callback({ ok = true })
		else
			callback({ ok = false, error = result.error })
		end
	end)
end

--- @param callback fun(result: {ok: boolean, error?: string})
M.image_prune = function(callback)
	run_docker_command({ "image", "prune", "-f" }, function(result)
		if result.ok then
			callback({ ok = true })
		else
			callback({ ok = false, error = result.error })
		end
	end)
end

--- @param network_id string
--- @param action "rm"
--- @param callback fun(result: {ok: boolean, error?: string})
M.network_action = function(network_id, action, callback)
	run_docker_command({ "network", action, network_id }, function(result)
		if result.ok then
			callback({ ok = true })
		else
			callback({ ok = false, error = result.error })
		end
	end)
end

--- @class ContainerStats
--- @field cpu_perc string
--- @field mem_usage string
--- @field mem_perc string
--- @field net_io string
--- @field block_io string
--- @field pids string

--- @param container_id string
--- @param callback fun(result: {ok: boolean, data?: ContainerStats, error?: string})
M.container_stats = function(container_id, callback)
	local format = table.concat({
		"{",
		'  "cpu_perc": {{json .CPUPerc}},',
		'  "mem_usage": {{json .MemUsage}},',
		'  "mem_perc": {{json .MemPerc}},',
		'  "net_io": {{json .NetIO}},',
		'  "block_io": {{json .BlockIO}},',
		'  "pids": {{json .PIDs}}',
		"}",
	}, "")

	run_docker_command({ "stats", "--no-stream", "--format", format, container_id }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		local line = result.data:match("[^\r\n]+")
		if line == nil or line == "" then
			callback({ ok = false, error = "No stats output" })
			return
		end

		local ok, parsed = pcall(vim.json.decode, line)
		if not ok or parsed == nil then
			callback({ ok = false, error = "Failed to parse stats data" })
			return
		end

		callback({ ok = true, data = parsed })
	end)
end

--- @param type "container"|"image"|"network"
--- @param id string
--- @param callback fun(result: {ok: boolean, data?: table, error?: string})
M.inspect = function(type, id, callback)
	run_docker_command({ "inspect", "--type", type, id }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		local ok, parsed = pcall(vim.json.decode, result.data)
		if ok and parsed and #parsed > 0 then
			callback({ ok = true, data = parsed[1] })
		else
			callback({ ok = false, error = "Failed to parse inspect data" })
		end
	end)
end

return M
