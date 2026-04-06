local M = {}

local highlights = require("dockyard.ui.highlights")

local LABEL_WIDTH = 14

local function v(x)
	if x == nil or x == vim.NIL then
		return "-"
	end
	local s = tostring(x)
	return s ~= "" and s or "-"
end

---@param lines string[]
---@param spans table[]
---@param label string
---@param value string
---@param value_hl string|nil
local function add_row(lines, spans, label, value, value_hl)
	local lbl = label .. ":"
	local pad = math.max(1, LABEL_WIDTH - #lbl)
	local text = "  " .. lbl .. string.rep(" ", pad) .. value
	local line_idx = #lines
	table.insert(lines, text)
	table.insert(spans, { line = line_idx, start_col = 2, end_col = 2 + #lbl, hl_group = "DockyardColumnHeader" })
	local val_start = 2 + #lbl + pad
	table.insert(
		spans,
		{ line = line_idx, start_col = val_start, end_col = val_start + #value, hl_group = value_hl or "DockyardName" }
	)
end

---@param item Container
---@return string[], table[]
local function build_container(item)
	local lines, spans = {}, {}
	local status = v(item.status)
	add_row(lines, spans, "Status", status:upper(), highlights.status_hl(item.status))
	add_row(lines, spans, "Image", v(item.image), "DockyardImage")
	if item.ports and item.ports ~= "" and item.ports ~= "-" then
		add_row(lines, spans, "Ports", v(item.ports), "DockyardPorts")
	end
	if item.networks and item.networks ~= "" then
		add_row(lines, spans, "Networks", v(item.networks), "DockyardMuted")
	end
	add_row(lines, spans, "Created", v(item.created_since), "DockyardMuted")
	if item.compose_project then
		table.insert(lines, "")
		add_row(lines, spans, "Project", v(item.compose_project), "DockyardMuted")
		if item.compose_service then
			add_row(lines, spans, "Service", v(item.compose_service), "DockyardMuted")
		end
	end
	return lines, spans
end

---@param item Image
---@return string[], table[]
local function build_image(item)
	local lines, spans = {}, {}
	local repo = v(item.repository)
	local tag = v(item.tag)
	local full = (tag ~= "-" and tag ~= "") and (repo .. ":" .. tag) or repo
	add_row(lines, spans, "Repository", full, "DockyardImage")
	add_row(lines, spans, "ID", v(item.id):sub(1, 12), "DockyardMuted")
	add_row(lines, spans, "Size", v(item.size), "DockyardPorts")
	add_row(lines, spans, "Created", v(item.created_since), "DockyardMuted")
	return lines, spans
end

---@param item Network
---@return string[], table[]
local function build_network(item)
	local lines, spans = {}, {}
	add_row(lines, spans, "Driver", v(item.driver), "DockyardName")
	add_row(lines, spans, "Scope", v(item.scope), "DockyardMuted")
	add_row(lines, spans, "ID", v(item.id):sub(1, 12), "DockyardMuted")
	add_row(lines, spans, "Created", v(item.created), "DockyardMuted")
	return lines, spans
end

---@param item Volume
---@return string[], table[]
local function build_volume(item)
	local lines, spans = {}, {}
	add_row(lines, spans, "Driver", v(item.driver), "DockyardName")
	add_row(lines, spans, "Scope", v(item.scope), "DockyardMuted")
	add_row(lines, spans, "Mountpoint", v(item.mountpoint), "DockyardMuted")
	return lines, spans
end

local _win = nil

local function close()
	if _win and vim.api.nvim_win_is_valid(_win) then
		vim.api.nvim_win_close(_win, true)
	end
	_win = nil
end

---@param title string
---@param lines string[]
---@param spans table[]
local function show(title, lines, spans)
	close()

	if #lines == 0 then
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	local ns = vim.api.nvim_create_namespace("dockyard.hover")
	for _, span in ipairs(spans) do
		local line_text = lines[span.line + 1] or ""
		local end_col = math.min(span.end_col, #line_text)
		if end_col > span.start_col then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
				end_row = span.line,
				end_col = end_col,
				hl_group = span.hl_group,
			})
		end
	end

	local max_width = 0
	for _, line in ipairs(lines) do
		max_width = math.max(max_width, #line)
	end
	local title_min = #title + 4
	max_width = math.max(max_width, title_min)

	local source_buf = vim.api.nvim_get_current_buf()

	_win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = max_width + 2,
		height = #lines,
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
		focusable = false,
		zindex = 260,
	})

	vim.api.nvim_set_option_value("wrap", false, { win = _win })

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
		buffer = source_buf,
		once = true,
		callback = function()
			close()
		end,
	})
end

---@param node { kind: string, item: Container|Image|Network|Volume }
function M.open(node)
	if not node or not node.item then
		return
	end

	local title, lines, spans
	if node.kind == "container" then
		title = v(node.item.name)
		lines, spans = build_container(node.item)
	elseif node.kind == "image" then
		local repo = v(node.item.repository)
		local tag = v(node.item.tag)
		title = (tag ~= "-" and tag ~= "") and (repo .. ":" .. tag) or repo
		lines, spans = build_image(node.item)
	elseif node.kind == "network" then
		title = v(node.item.name)
		lines, spans = build_network(node.item)
	elseif node.kind == "volume" then
		title = v(node.item.name)
		lines, spans = build_volume(node.item)
	else
		return
	end

	show(title, lines, spans)
end

return M
