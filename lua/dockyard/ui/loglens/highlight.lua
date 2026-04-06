local M = {}

local color_group_cache = {}

local function is_hex_color(str)
	return type(str) == "string" and str:match("^#%x%x%x%x%x%x$")
end

---Normalize and validate rules
---@param rules LogHighlightRule[]|nil
---@return table
function M.normalize_rules(rules)
	local normalized = {}
	if type(rules) ~= "table" then
		return normalized
	end

	for _, rule in ipairs(rules) do
		if type(rule) ~= "table" then
			goto continue
		end

		local pattern = rule.pattern
		local group = rule.group
		local color = rule.color

		if type(pattern) ~= "string" or pattern == "" then
			goto continue
		end

		local out = { pattern = pattern }
		if type(group) == "string" and group ~= "" then
			out.group = group
		end

		if type(color) == "string" and color ~= "" then
			local lowered = color:lower()
			if is_hex_color(lowered) then
				out.color = lowered
			end
		end

		if out.group ~= nil or out.color ~= nil then
			table.insert(normalized, out)
		end

		::continue::
	end

	return normalized
end

---Resolve a usable highlight group for one rule.
---@param rule LogHighlightRule
---@return string|nil
function M.resolve_hl_group(rule)
	if rule.group then
		return rule.group
	end

	if not rule.color then
		return nil
	end

	local key = rule.color:sub(2)
	local group = color_group_cache[key]
	if group then
		return group
	end

	group = "DockyardLogLensColor_" .. key
	vim.api.nvim_set_hl(0, group, { fg = rule.color })
	color_group_cache[key] = group

	return group
end

---@param line_text string
---@param rules table
---@param line_index number 0-based buffer line
---@param start_col_offset number|nil
---@return table
function M.find_spans(line_text, rules, line_index, start_col_offset)
	local spans = {}
	local offset = start_col_offset or 0

	for _, rule in ipairs(rules) do
		local hl_group = M.resolve_hl_group(rule)
		if hl_group then
			local init = 1
			while init <= #line_text do
				local s, e = string.find(line_text, rule.pattern, init)
				if not s then
					break
				end

				local start_col = offset + (s - 1)
				local end_col = offset + e

				if end_col > start_col then
					table.insert(spans, {
						line = line_index,
						start_col = start_col,
						end_col = end_col,
						hl_group = hl_group,
					})
				end

				-- Prevent infinite loops for pathological/zero-width-like matches.
				if e < init then
					init = init + 1
				else
					init = e + 1
				end
			end
		end
	end

	return spans
end

---Apply extmarks to body lines only.
---@param buf number
---@param ns number
---@param lines string[]
---@param line_map table
---@param rules LogHighlightRule[]|nil
function M.apply(buf, ns, lines, line_map, rules)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local normalized = M.normalize_rules(rules)
	if #normalized == 0 then
		return
	end

	for lnum, _ in pairs(line_map or {}) do
		local idx = tonumber(lnum)
		if idx and idx >= 1 then
			local line_text = lines[idx] or ""
			local spans = M.find_spans(line_text, normalized, idx - 1, 0)

			for _, span in ipairs(spans) do
				vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
					end_row = span.line,
					end_col = span.end_col,
					hl_group = span.hl_group,
				})
			end
		end
	end
end

return M
