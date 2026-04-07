local M = {}

local COMPOSE_FILENAMES = {
	"docker-compose.yml",
	"docker-compose.yaml",
	"compose.yml",
	"compose.yaml",
}

---@return string|nil
function M.current_file()
	local buf = vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return nil
	end
	return name
end

---@return string|nil
function M.current_dir()
	local file = M.current_file()
	if file then
		return vim.fn.fnamemodify(file, ":h")
	end
	return vim.fn.getcwd()
end

---@param file string
---@return boolean
function M.is_dockerfile(file)
	local basename = vim.fn.fnamemodify(file, ":t")
	if basename == "Dockerfile" then
		return true
	end
	if basename:match("^Dockerfile%.") then
		return true
	end
	return false
end

---@param file string
---@return boolean
function M.is_compose_file(file)
	local basename = vim.fn.fnamemodify(file, ":t")
	for _, name in ipairs(COMPOSE_FILENAMES) do
		if basename == name then
			return true
		end
	end
	return false
end

---Find a compose file in the given directory only.
---TODO: Might wanna search the git directory of the Project instead of just the current dir, but this is a start.
---@param dir string
---@return string|nil
function M.find_compose_file(dir)
	for _, name in ipairs(COMPOSE_FILENAMES) do
		local path = dir .. "/" .. name
		if vim.loop.fs_stat(path) then
			return path
		end
	end
	return nil
end

---Try to detect the compose service name under the cursor.
---Only works when the current buffer is a compose file.
---@return string|nil
function M.service_at_cursor()
	local file = M.current_file()
	if not file or not M.is_compose_file(file) then
		return nil
	end

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	-- Walk backwards from cursor to find the nearest service key.
	-- Services are top-level keys under "services:" with no indentation beyond 2 spaces.
	local in_services = false
	local last_service = nil

	for i = 1, #buf_lines do
		local line = buf_lines[i]

		if line:match("^services:") then
			in_services = true
			last_service = nil
		elseif in_services then
			-- A new top-level key ends the services block
			if line:match("^%S") and not line:match("^%s*#") then
				if i <= cursor_line then
					in_services = false
					last_service = nil
				else
					break
				end
			end

			-- Service name: exactly 2 spaces indent, then a word followed by colon
			local service = line:match("^  ([%w_%-]+):%s*$") or line:match("^  ([%w_%-]+):%s+")
			if service and i <= cursor_line then
				last_service = service
			end
		end

		if i == cursor_line then
			break
		end
	end

	return last_service
end

---Extract service names that appear within the given line range of the current buffer.
---@param line1 integer 1-based start line
---@param line2 integer 1-based end line
---@return string[]
function M.services_in_range(line1, line2)
	local file = M.current_file()
	if not file or not M.is_compose_file(file) then
		return {}
	end

	local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local services = {}
	local in_services = false

	for i, line in ipairs(buf_lines) do
		if line:match("^services:") then
			in_services = true
		elseif in_services then
			if line:match("^%S") and not line:match("^%s*#") then
				in_services = false
			else
				local service = line:match("^  ([%w_%-]+):%s*$") or line:match("^  ([%w_%-]+):%s+")
				if service and i >= line1 and i <= line2 then
					table.insert(services, service)
				end
			end
		end
	end

	return services
end

---@class DockyardContext
---@field type "dockerfile"|"compose"|"project"|nil
---@field file string|nil
---@field dir string
---@field service string|nil

---Detect the docker context for the current buffer.
---@return DockyardContext
function M.detect()
	local file = M.current_file()
	local dir = M.current_dir() or vim.fn.getcwd()

	if file and M.is_dockerfile(file) then
		return { type = "dockerfile", file = file, dir = vim.fn.fnamemodify(file, ":h") }
	end

	if file and M.is_compose_file(file) then
		return {
			type = "compose",
			file = file,
			dir = vim.fn.fnamemodify(file, ":h"),
			service = M.service_at_cursor(),
		}
	end

	-- Not in a docker file, try to find a compose file nearby
	local compose = M.find_compose_file(dir)
	if compose then
		return {
			type = "project",
			file = compose,
			dir = vim.fn.fnamemodify(compose, ":h"),
		}
	end

	return { type = nil, file = nil, dir = dir }
end

return M
