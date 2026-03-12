local M = {}

---@param container Container
---@param source LogSource
---@param tail number
---@return string[]
local function build_command(container, source, tail)
	if source.path and source.path ~= "" then
		return { "docker", "exec", container.id, "tail", "-n", tostring(tail), "-f", source.path }
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
---@return number|nil
function M.start(container, source, tail, on_chunk, on_exit)
	local cmd = build_command(container, source, tail)
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
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

	return job_id
end

---@param job_id number|nil
function M.stop(job_id)
	if job_id and job_id > 0 then
		pcall(vim.fn.jobstop, job_id)
	end
end

return M
