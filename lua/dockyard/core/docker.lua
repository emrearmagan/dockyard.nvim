local M = {}

local job = require("plenary.job")

---Detect whether an container is in an in-progress transition.
---@param container Container|nil
---@return boolean
function M.is_transitional_status(container)
	if not container or not container.status_message then
		return false
	end

	-- if container.name and container.name:find("backend", 1, true) then
	-- 	return true
	-- end
	-- return false

	if container.status == "restarting" or container.status == "starting" or container.status == "removing" then
		return true
	end

	return false
end

---Detect whether any container is in an in-progress transition.
---@param containers Container[]|nil
---@return boolean
function M.has_transitional_status(containers)
	for _, container in ipairs(containers or {}) do
		if M.is_transitional_status(container) then
			return true
		end
	end

	return false
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

---@alias ContainerStatus
---| "created"
---| "running"
---| "paused"
---| "starting"
---| "restarting"
---| "removing"
---| "exited"
---| "dead"
---| "unknown"

--- @class Container
--- @field id string
--- @field name string
--- @field image string
--- @field command string
--- @field status ContainerStatus
--- @field status_message string
--- @field ports string
--- @field networks string
--- @field created string
--- @field created_since string
--- @field labels string
--- @field compose_project string|nil
--- @field compose_service string|nil

---Extract a label value from docker ps label string (key=val,key=val).
---@param labels string|nil
---@param key string
---@return string|nil
local function extract_compose_label(labels, key)
	if type(labels) ~= "string" or labels == "" then
		return nil
	end
	for pair in labels:gmatch("([^,]+)") do
		local k, val = pair:match("^(.-)=(.*)$")
		if k == key and val and val ~= "" then
			return val
		end
	end
	return nil
end

---@return string
local function format_ports(ports)
	if not ports or ports == "" then
		return ""
	end

	local seen = {}
	local result = {}

	for part in ports:gmatch("[^,]+") do
		part = part:gsub("^%s+", ""):gsub("%s+$", "")

		-- mapped ports
		local host, container = part:match(":(%d+%-?%d*)%->(%d+%-?%d*)")
		if host and container then
			local key = host .. "→" .. container
			if not seen[key] then
				seen[key] = true
				table.insert(result, key)
			end
		else
			-- exposed only
			local port = part:match("^(%d+%-?%d*)/tcp")
			if port and not seen[port] then
				seen[port] = true
				table.insert(result, port)
			end
		end
	end

	return table.concat(result, ", ")
end

--- @alias ContainerCallback fun(result: {ok: boolean, data: Container[], error?: string})
function M.list_containers(callback)
	local format = table.concat({
		"{",
		'  "id": {{json .ID}},',
		'  "name": {{json .Names}},',
		'  "image": {{json .Image}},',
		'  "command": {{json .Command}},',
		'  "status": {{json .State}},',
		'  "status_message": {{json .Status}},',
		'  "ports": {{json .Ports}},',
		'  "networks": {{json .Networks}},',
		'  "created": {{json .CreatedAt}},',
		'  "created_since": {{json .RunningFor}},',
		'  "labels": {{json .Labels}}',
		"}",
	}, "")

	run_docker_command({ "ps", "-a", "--format", format }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		local valid_status = {
			created = true,
			running = true,
			paused = true,
			restarting = true,
			removing = true,
			exited = true,
			dead = true,
		}

		local function normalize_status(status, status_message)
			if not valid_status[status] then
				return "unknown"
			end

			local msg = status_message or ""

			if status == "restarting" then
				return "restarting"
			end

			if status == "paused" then
				return "paused"
			end

			if status == "removing" then
				return "removing"
			end

			if status == "dead" then
				return "dead"
			end

			if status == "created" then
				return "created"
			end

			if status == "exited" then
				return "exited"
			end

			if status == "running" then
				if msg:find("(health: starting)", 1, true) or msg:find("(starting)", 1, true) then
					return "starting"
				end

				if msg:find("(unhealthy)", 1, true) then
					return "dead"
				end

				return "running"
			end

			return "unknown"
		end

		--- @type Container[]
		local containers = {}
		if result.data ~= "" then
			for line in result.data:gmatch("[^\r\n]+") do
				local ok, parsed = pcall(vim.json.decode, line)
				if ok and parsed then
					parsed.status = normalize_status(parsed.status, parsed.status_message)
					parsed.compose_project = extract_compose_label(parsed.labels, "com.docker.compose.project")
					parsed.compose_service = extract_compose_label(parsed.labels, "com.docker.compose.service")
					parsed.ports = format_ports(parsed.ports)
					table.insert(containers, parsed)
				else
					vim.notify("Failed to parse container line: " .. line, vim.log.levels.WARN)
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

--- @class Volume
--- @field name string
--- @field driver string
--- @field mountpoint string
--- @field scope string
--- @field labels string

--- @param callback fun(result: {ok: boolean, data: Volume[], error?: string})
M.list_volumes = function(callback)
	local format = table.concat({
		"{",
		'  "name": {{json .Name}},',
		'  "driver": {{json .Driver}},',
		'  "mountpoint": {{json .Mountpoint}},',
		'  "scope": {{json .Scope}},',
		'  "labels": {{json .Labels}}',
		"}",
	}, "")

	run_docker_command({ "volume", "ls", "--format", format }, function(result)
		if not result.ok then
			callback(result)
			return
		end

		--- @type Volume[]
		local volumes = {}
		if result.data ~= "" then
			for line in result.data:gmatch("[^\r\n]+") do
				local ok, parsed = pcall(vim.json.decode, line)
				if ok and parsed then
					table.insert(volumes, parsed)
				end
			end
		end

		callback({ ok = true, data = volumes })
	end)
end

--- @param volume_name string
--- @param action "rm"
--- @param callback fun(result: {ok: boolean, error?: string})
M.volume_action = function(volume_name, action, callback)
	run_docker_command({ "volume", action, volume_name }, function(result)
		if result.ok then
			callback({ ok = true })
		else
			callback({ ok = false, error = result.error })
		end
	end)
end

--- @param container_id string
--- @param action "start"|"stop"|"restart"|"rm"
--- @param callback fun(result: {ok: boolean, error?: string})
M.container_action = function(container_id, action, callback)
	run_docker_command({ action, container_id }, function(result)
		if result.ok then
			callback({ ok = true, error = nil })
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
	run_docker_command({ "image", "prune", "-f", "-a" }, function(result)
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
--- @param on_stats fun(data: ContainerStats)
--- @return fun() stop
M.stream_stats = function(container_id, on_stats)
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

	local job_id = vim.fn.jobstart({ "docker", "stats", "--format", format, container_id }, {
		on_stdout = function(_, data)
			for _, line in ipairs(data) do
				-- Strip ANSI escape sequences (Docker uses ESC[H / ESC[K for terminal refresh)
				line = line:gsub("\027%[[%d;]*[A-Za-z]", ""):gsub("\r", ""):match("^%s*(.-)%s*$")
				if line ~= "" then
					local ok, parsed = pcall(vim.json.decode, line)
					if ok and parsed then
						on_stats(parsed)
					end
				end
			end
		end,
	})

	return function()
		if job_id and job_id > 0 then
			pcall(vim.fn.jobstop, job_id)
		end
	end
end

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

--- @param container_id string
--- @param callback fun(result: {ok: boolean, data?: string, error?: string})
M.container_top = function(container_id, callback)
	run_docker_command({ "top", container_id }, function(result)
		if not result.ok then
			callback(result)
			return
		end
		callback({ ok = true, data = result.data })
	end)
end

--- @param type "container"|"image"|"network"|"volume"
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
