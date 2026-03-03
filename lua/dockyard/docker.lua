local M = {}
local job = require("plenary.job")

local function run_docker_command(args, callback)
	job:new({
		command = "docker",
		args = args,
		on_exit = function(j, return_val)
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
		end,
	}):start()
end

--- @class Container
--- @field id string
--- @field name string[]
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

--- @alias ImageCallback fun(result: {ok: boolean, data: Image[], error?: string})

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

--- @alias NetworkCallback fun(result: {ok: boolean, data: Network[], error?: string})

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

return M
