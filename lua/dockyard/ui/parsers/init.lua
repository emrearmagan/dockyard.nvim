local M = {}

---Default JSON log parser
---@param line string
---@return table|nil
function M.json(line)
	local ok, res = pcall(vim.json.decode, line)
	if not ok or not res then return nil end

	local msg = res.message or res.msg or res.log or line
	local level = (res.level or "info"):upper()
	local ts = ""
	
	if res.timestamp then
		-- Try to extract HH:MM:SS or just take first 10 chars
		ts = tostring(res.timestamp):match("T(%d%d:%d%d:%d%d)") or tostring(res.timestamp):sub(1, 10)
	else
		ts = "        "
	end

	return {
		data = res,
		row = string.format("%-8s │ %-7s │ %s", ts, level, msg),
		raw = line,
		detail = line,
		highlight = function(buf, lnum, offset)
			local hl_group = "Identifier"
			if level == "ERROR" or level == "CRITICAL" then
				hl_group = "ErrorMsg"
			elseif level == "WARN" or level == "WARNING" then
				hl_group = "WarningMsg"
			end

			-- Highlight the level badge
			-- Offset + Timestamp(8) + Space(1) + Separator(1) + Space(1) = 11
			local start_col = (offset or 0) + 11
			vim.api.nvim_buf_add_highlight(buf, -1, hl_group, lnum, start_col, start_col + #level)
		end
	}
end

---Default Plain Text log parser
---@param line string
---@return table
function M.text(line)
	return {
		row = line,
		raw = line,
		detail = line
	}
end

return M
