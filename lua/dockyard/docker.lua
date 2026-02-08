local Job = require("plenary.job")

local M = {}

local FORMAT =
	[[{"id": {{json .ID}}, "name": {{json .Names}}, "image": {{json .Image}}, "command": {{json .Command}}, "status": {{json .Status}}, "ports": {{json .Ports}}, "networks": {{json .Networks}}, "created": {{json .CreatedAt}}, "created_since": {{json .RunningFor}}}]]

local IMG_FORMAT =
	[[{"id": {{json .ID}}, "repository": {{json .Repository}}, "tag": {{json .Tag}}, "created": {{json .CreatedAt}}, "created_since": {{json .CreatedSince}}, "size": {{json .Size}}}]]

local function run_docker(args, opts)
	local job_opts = vim.tbl_deep_extend("force", opts or {}, {
		command = "docker",
		args = args,
	})
	return Job:new(job_opts)
end

local function decode_line(line)
	if not line or line == "" then
		return nil
	end
	local ok, decoded = pcall(vim.json.decode, line)
	if not ok then
		return nil
	end
	return decoded
end

local function parse_lines(lines)
	local containers = {}
	for _, line in ipairs(lines or {}) do
		local entry = decode_line(line)
		if entry then
			containers[#containers + 1] = entry
		end
	end
	return containers
end

function M.list_containers(opts)
	opts = opts or {}
	local job = run_docker({
		"container",
		"ls",
		"-a",
		"--format",
		FORMAT,
	}, opts.job)

	local ok, result = pcall(function()
		return job:sync(opts.timeout or 10000)
	end)

	if not ok then
		return {}, "failed to run docker"
	end

	return parse_lines(result)
end

function M.list_images(opts)
	opts = opts or {}
	local job = run_docker({
		"image",
		"ls",
		"--format",
		IMG_FORMAT,
	}, opts.job)

	local ok, result = pcall(function()
		return job:sync(opts.timeout or 10000)
	end)

	if not ok then
		return {}, "failed to run docker"
	end

	return parse_lines(result)
end

return M
