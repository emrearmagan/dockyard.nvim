local M = {}

local context = require("dockyard.commands.context")
local builder = require("dockyard.commands.builder")
local executor = require("dockyard.commands.executor")

local function save_if_modified()
	if vim.bo.modified then
		vim.cmd("silent! write")
	end
end

function M.build()
	save_if_modified()
	local ctx = context.detect()

	if ctx.type ~= "dockerfile" then
		vim.notify("Dockyard: not in a Dockerfile context", vim.log.levels.WARN)
		return
	end

	local args, err = builder.build_cmd(ctx)
	if not args then
		vim.notify("Dockyard: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	executor.run(args, { cwd = ctx.dir, title = "docker build" })
end

---@param line1 integer 1-based start line
---@param line2 integer 1-based end line
function M.run_visual(line1, line2)
	save_if_modified()
	local file = context.current_file()
	if not file or not context.is_compose_file(file) then
		vim.notify("Dockyard: not in a compose file", vim.log.levels.WARN)
		return
	end

	local ctx = {
		type = "compose",
		file = file,
		dir = vim.fn.fnamemodify(file, ":h"),
	}

	local services = context.services_in_range(line1, line2)
	if #services == 0 then
		vim.notify("Dockyard: no services found in selection", vim.log.levels.WARN)
		return
	end

	local args, err = builder.run_cmd(ctx, services)
	if not args then
		vim.notify("Dockyard: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	executor.run(args, { cwd = ctx.dir, title = "compose up " .. table.concat(services, ", ") })
end

function M.run_all()
	save_if_modified()
	local ctx = context.detect()

	if ctx.type ~= "compose" and ctx.type ~= "project" then
		vim.notify("Dockyard: no compose file found", vim.log.levels.WARN)
		return
	end

	local args, err = builder.run_all_cmd(ctx)
	if not args then
		vim.notify("Dockyard: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	executor.run(args, { cwd = ctx.dir, title = "compose up" })
end

return M
