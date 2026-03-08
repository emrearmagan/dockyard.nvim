local M = {}

---@param source LogSource
---@param entry table
---@return table|nil
local function format_row(source, entry)
	local ok, row = pcall(source.format, entry)
	if not ok or type(row) ~= "table" then
		return nil
	end

	return row
end

---@param source LogSource
---@return LogLensParserSession
function M.create(source)
	local pending = ""

	---@type LogLensParserSession
	local session = {}

	---@param chunk string
	---@return table[]
	function session:push(chunk)
		pending = pending .. chunk
		local rows = {}
		while true do
			local idx = pending:find("\n", 1, true)
			if not idx then
				break
			end
			local line = pending:sub(1, idx - 1)
			pending = pending:sub(idx + 1)
			local row = format_row(source, { raw = line, message = line })
			if row then
				table.insert(rows, row)
			end
		end
		return rows
	end

	---@return table[]
	function session:flush()
		if pending == "" then
			return {}
		end
		local line = pending
		pending = ""
		local row = format_row(source, { raw = line, message = line })
		if row then
			return { row }
		end
		return {}
	end

	return session
end

return M
