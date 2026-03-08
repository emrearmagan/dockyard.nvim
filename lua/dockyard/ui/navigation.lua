local M = {}

local ui_state = require("dockyard.ui.state")

---@return integer[]
local function sorted_row_lines()
	---@type integer[]
	local lines = {}
	for lnum, _ in pairs(ui_state.line_map or {}) do
		if type(lnum) == "number" then
			table.insert(lines, lnum)
		end
	end
	table.sort(lines)
	return lines
end

---@param lines integer[]
---@param current_line integer
---@return integer?
local function nearest_row_index(lines, current_line)
	if #lines == 0 then
		return nil
	end

	for i, l in ipairs(lines) do
		if l == current_line then
			return i
		end

		if current_line < lines[1] then
			return 1
		end

		if current_line > lines[#lines] then
			return #lines
		end

		for i = 1, #lines - 1 do
			local a = lines[i]
			local b = lines[i + 1]
			if current_line > a and current_line < b then
				if (current_line - a) <= (b - current_line) then
					return i
				end
				return i + 1
			end
		end
	end

	return #lines
end

---@param step integer
local function move(step)
	local lines = sorted_row_lines()
	if #lines == 0 then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local idx = nearest_row_index(lines, cursor[1])
	if idx == nil then
		return
	end

	local target_idx = idx + step
	if target_idx < 1 then
		target_idx = 1
	elseif target_idx > #lines then
		target_idx = #lines
	end

	vim.api.nvim_win_set_cursor(0, { lines[target_idx], 0 })
end

function M.down()
	move(1)
end

function M.up()
	move(-1)
end

function M.first()
	local lines = sorted_row_lines()
	if #lines == 0 then
		return
	end
	vim.api.nvim_win_set_cursor(0, { lines[1], 0 })
end

function M.last()
	local lines = sorted_row_lines()
	if #lines == 0 then
		return
	end
	vim.api.nvim_win_set_cursor(0, { lines[#lines], 0 })
end

return M
