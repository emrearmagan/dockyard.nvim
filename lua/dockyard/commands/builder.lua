local M = {}

---@return string[] base command parts
local function compose_base()
	if vim.fn.executable("docker") == 1 then
		return { "docker", "compose" }
	end
	return { "docker-compose" }
end

---@param ctx DockyardContext
---@return string[]|nil args, string|nil error
function M.build_cmd(ctx)
	if not ctx or not ctx.file then
		return nil, "No docker file found"
	end

	if ctx.type == "dockerfile" then
		local dir = ctx.dir
		local tag = vim.fn.fnamemodify(dir, ":t"):lower():gsub("[^%w%-_]", "")
		if tag == "" then
			tag = "dockyard-build"
		end
		local args = { "docker", "build", "-f", ctx.file, "-t", tag, dir }
		return args, nil
	end

	return nil, "Cannot build command for context type: " .. tostring(ctx.type)
end

---@param ctx DockyardContext
---@param services string|string[]|nil
---@return string[]|nil args, string|nil error
function M.run_cmd(ctx, services)
	if not ctx or not ctx.file then
		return nil, "No compose file found"
	end

	if ctx.type ~= "compose" and ctx.type ~= "project" then
		return nil, "Not a compose context"
	end

	local base = compose_base()
	local args = vim.list_extend({}, base)
	table.insert(args, "-f")
	table.insert(args, ctx.file)
	table.insert(args, "up")
	table.insert(args, "-d")
	table.insert(args, "--force-recreate")

	if type(services) == "string" and services ~= "" then
		table.insert(args, services)
	elseif type(services) == "table" then
		for _, s in ipairs(services) do
			table.insert(args, s)
		end
	end

	return args, nil
end

---@param ctx DockyardContext
---@return string[]|nil args, string|nil error
function M.run_all_cmd(ctx)
	return M.run_cmd(ctx, nil)
end

return M
