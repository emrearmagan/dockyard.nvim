local M = {}

---Generate fake log entries for UI development.
---@param count number|nil
---@return LogLensEntry[]
function M.generate(count)
	count = count or 40

	---@type LogLensEntry[]
	local rows = {}
	for i = 1, count do
		local second = i % 60
		table.insert(rows, string.format("2026-03-08T14:00:%02dZ fake log line %d", second, i))
	end

	return rows
end

return M
