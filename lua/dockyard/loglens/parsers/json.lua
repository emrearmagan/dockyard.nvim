local M = {}

---@param source LogSource
---@param raw string
---@return LogLensEntry|nil
local function parse_and_format(source, raw)
	local ok, decoded = pcall(vim.json.decode, raw)
	if not ok or type(decoded) ~= "table" then
		return nil
	end

	local ok_fmt, row = pcall(source.format, decoded)
	if not ok_fmt or type(row) ~= "table" then
		return nil
	end

	return {
		raw = raw,
		data = row,
	}
end

---@param source LogSource
---@return LogLensParserSession
function M.create(source)
	local buffer = ""
	local session = {}

	---@param chunk string
	---@return LogLensEntry[]
	function session:push(chunk)
		buffer = buffer .. chunk .. "\n"
		local rows = {}
		local i, len = 1, #buffer
		local started, start_idx, depth = false, 1, 0
		local in_string, escape_next = false, false

		while i <= len do
			local ch = buffer:sub(i, i)
			if not started then
				if ch == "{" or ch == "[" then
					started, start_idx, depth = true, i, 1
				end
			else
				if in_string then
					if escape_next then
						escape_next = false
					elseif ch == "\\" then
						escape_next = true
					elseif ch == '"' then
						in_string = false
					end
				else
					if ch == '"' then
						in_string = true
					elseif ch == "{" or ch == "[" then
						depth = depth + 1
					elseif ch == "}" or ch == "]" then
						depth = depth - 1
						if depth == 0 then
							local record = buffer:sub(start_idx, i)
							local row = parse_and_format(source, record)
							if row then
								table.insert(rows, row)
							end
							buffer = buffer:sub(i + 1)
							len, i = #buffer, 0
							started, start_idx, depth = false, 1, 0
							in_string, escape_next = false, false
						end
					end
				end
			end
			i = i + 1
		end

		return rows
	end

	---@return LogLensEntry[]
	function session:flush()
		local trimmed = buffer:gsub("^%s+", ""):gsub("%s+$", "")
		buffer = ""
		if trimmed == "" then
			return {}
		end
		local row = parse_and_format(source, trimmed)
		if row then
			return { row }
		end
		return {}
	end

	---@cast session LogLensParserSession
	return session
end

return M
