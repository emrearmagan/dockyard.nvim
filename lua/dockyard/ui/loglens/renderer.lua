local M = {}

local header = require("dockyard.ui.loglens.header")
local table_renderer = require("dockyard.ui.components.table")
local highlighter = require("dockyard.ui.loglens.highlight")
local ns = vim.api.nvim_create_namespace("dockyard.loglens")

---@param state LogLensState
---@return boolean
local function is_valid_state(state)
	return state.buf_id ~= nil
		and vim.api.nvim_buf_is_valid(state.buf_id)
		and state.win_id ~= nil
		and vim.api.nvim_win_is_valid(state.win_id)
end

---@param rows table[]
---@param order string[]|nil
---@return table[]
---Infer table columns from the first formatted row. Might later be extended to support multiple rows and more complex logic.
---
---If `order` is provided (from `source._order`), keys are taken in that order.
---Otherwise, keys are taken from the first row table.
---
---Examples:
---  row = { time = "12:00:00", level = "INFO", message = "ok" }
---  order = { "time", "level", "message" }
---  -> columns: Time, Level, Message
---
---  row = { message = "ok", level = "INFO" }
---  order = nil
---  -> columns inferred from row keys
local function infer_columns(rows, order)
	local first = rows[1]
	if type(first) ~= "table" then
		return {}
	end

	local cols = {}
	if type(order) == "table" then
		for _, key in ipairs(order) do
			if type(key) == "string" and first[key] ~= nil then
				table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
			end
		end
	else
		for key, _ in pairs(first) do
			table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
		end
	end

	if #cols == 0 then
		return {}
	end

	return cols
end

---@param entries LogLensEntry[]
---@param raw boolean
---@param filter string|nil
---@param active_source_idx number|nil  0 = All, else source index
---@param show_source_col boolean  prepend "source" column (only on All with >1 source)
---@return table[]
local function to_rows(entries, raw, filter, active_source_idx, show_source_col)
	local rows = {}
	local row_to_entry = setmetatable({}, { __mode = "k" })
	local needle = nil
	if type(filter) == "string" and filter ~= "" then
		needle = filter:lower()
	end

	local function row_matches(row)
		if not needle then
			return true
		end

		for _, value in pairs(row) do
			local text
			if type(value) == "table" then
				text = vim.inspect(value)
			else
				text = tostring(value or "")
			end

			if text:lower():find(needle, 1, true) then
				return true
			end
		end

		return false
	end

	for _, entry in ipairs(entries or {}) do
		if type(entry) == "table" then
			if active_source_idx and active_source_idx > 0 and entry._source_idx ~= active_source_idx then
				goto continue
			end
			local row = nil
			if raw then
				row = { raw = tostring(entry.raw or "") }
			elseif type(entry.data) == "table" then
				if show_source_col then
					row = { source = entry._source_name or "" }
					for k, v in pairs(entry.data) do
						row[k] = v
					end
				else
					row = entry.data
				end
			end
			if row and row_matches(row) then
				table.insert(rows, row)
				row_to_entry[row] = entry
			end
		end
		::continue::
	end
	return rows, row_to_entry
end

---@param state LogLensState
function M.render(state)
	if not is_valid_state(state) then
		return
	end

	local sources = state.sources or {}
	local active_source_idx = state.active_source_idx or 0
	if active_source_idx > #sources then
		active_source_idx = 0
		state.active_source_idx = 0
	end
	local show_source_col = active_source_idx == 0 and #sources > 1 and not state.raw

	local winbar = header.render(state.container_name or "unknown", {
		follow = state.follow,
		raw = state.raw,
		filter = state.filter,
		sources = sources,
		active_source_idx = active_source_idx,
	})
	vim.api.nvim_set_option_value("winbar", winbar, { win = state.win_id })

	local source = state.active_source or {}
	if active_source_idx > 0 and sources[active_source_idx] then
		source = sources[active_source_idx]
	end
	local rows, row_to_entry = to_rows(state.entries, state.raw, state.filter, active_source_idx, show_source_col)
	local order = source._order
	if show_source_col and order then
		local prefixed = { "source" }
		for _, k in ipairs(order) do
			table.insert(prefixed, k)
		end
		order = prefixed
	elseif show_source_col and rows[1] then
		local prefixed = { "source" }
		for k, _ in pairs(rows[1]) do
			if k ~= "source" then
				table.insert(prefixed, k)
			end
		end
		order = prefixed
	end
	local columns = infer_columns(rows, state.raw and { "raw" } or order)
	if #columns == 0 then
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
		vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, {})
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })
		state.line_map = {}
		return
	end

	local width = vim.api.nvim_win_get_width(state.win_id)
	local lines, line_map = table_renderer.render({
		columns = columns,
		rows = rows,
		width = width,
		margin = 1,
		fill = false,
	})

	vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf_id })
	vim.api.nvim_buf_set_lines(state.buf_id, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf_id })
	if not state.raw then
		highlighter.apply(state.buf_id, ns, lines, line_map, source.highlights or {})
	end

	-- create a mapping from line to entry for later retrieval (e.g. shown for the popup)
	local resolved_line_map = {}
	for lnum, row in pairs(line_map or {}) do
		resolved_line_map[lnum] = row_to_entry[row] or row
	end
	state.line_map = resolved_line_map

	if state.follow then
		local n = vim.api.nvim_buf_line_count(state.buf_id)
		vim.api.nvim_win_set_cursor(state.win_id, { n, 0 })
	end
end

return M
