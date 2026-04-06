local M = {}

local jobs = require("dockyard.core.jobs")

---@class StreamHandle
---@field stop fun()

---@param container Container
---@param source LogSource
---@param tail number
---@return string[]
local function build_command(container, source, tail)
	if source.path and source.path ~= "" then
		-- Prefix with `echo $$` to print the shell PID before replacing the shell
		-- process with `exec tail` (which keeps the same PID). We capture this PID
		-- from the first stdout line so we can explicitly kill the tail process on
		-- stop — Docker does not signal exec'd processes when the host connection drops.
    --
    -- Just in case we also use the jobs.lua to track running processes, so we have a fallback cleanup mechanism if the PID capture fails for some reason.
		-- See: https://github.com/nvim-lua/plenary.nvim/issues/328
		return {
			"docker",
			"exec",
			container.id,
			"sh",
			"-c",
			string.format("echo $$; exec tail -n %d -f %s", tail, source.path),
		}
	end

	return { "docker", "logs", "--follow", "--tail", tostring(tail), container.id }
end

---@param data string[]|nil
---@param on_chunk fun(chunk: string)
local function emit_chunk(data, on_chunk)
	if not data or #data == 0 then
		return
	end
	local chunk = table.concat(data, "\n")
	if chunk ~= "" then
		on_chunk(chunk)
	end
end

---@param container Container
---@param source LogSource
---@param tail number
---@param on_chunk fun(chunk: string)
---@param on_exit fun()|nil
---@return StreamHandle|nil
function M.start(container, source, tail, on_chunk, on_exit)
	local inner_pid = nil
	local untrack = nil
	local is_exec = source.path and source.path ~= ""
	local cmd = build_command(container, source, tail)

	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			if is_exec and not inner_pid then
				for i, line in ipairs(data) do
					if line:match("^%d+$") then
						inner_pid = tonumber(line)
						untrack = jobs.track(container.id, inner_pid)
						table.remove(data, i)
						break
					end
				end
			end
			emit_chunk(data, on_chunk)
		end,
		on_stderr = function(_, data)
			emit_chunk(data, on_chunk)
		end,
		on_exit = function()
			if on_exit then
				on_exit()
			end
		end,
	})

	if type(job_id) ~= "number" or job_id <= 0 then
		return nil
	end

	return {
		stop = function()
			if untrack then untrack() end
			pcall(vim.fn.jobstop, job_id)
			if inner_pid then
				vim.fn.jobstart({ "docker", "exec", container.id, "kill", "-9", tostring(inner_pid) })
			end
		end,
	}
end

return M
