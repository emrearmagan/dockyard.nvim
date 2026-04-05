local M = {}

local data_state = require("dockyard.state")
local ui_state = require("dockyard.ui.state")
local config = require("dockyard.config")
local table_view = require("dockyard.ui.components.table")
local header = require("dockyard.ui.components.header")
local navbar = require("dockyard.ui.components.navbar")
local footer = require("dockyard.ui.components.footer")
local ui_utils = require("dockyard.ui.utils")
local view_state = require("dockyard.ui.views.volumes.state")
local icons = require("dockyard.ui.icons")

local function current_width()
	if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
		return vim.api.nvim_win_get_width(ui_state.win_id)
	end
	return vim.o.columns
end

local function build_rows(volumes)
	local rows = {}
	local sorted = vim.deepcopy(volumes or {})

	table.sort(sorted, function(a, b)
		return tostring(a.name or "") < tostring(b.name or "")
	end)

	for _, vol in ipairs(sorted) do
		table.insert(rows, {
			name = icons.volume_icon("default") .. " " .. (vol.name or "-"),
			driver = vol.driver or "-",
			scope = vol.scope or "-",
			mountpoint = vol.mountpoint or "-",
			_item = {
				kind = "volume",
				item = vol,
			},
		})
	end

	return rows
end

---@param volumes Volume[]
local function set_footer_items(volumes)
	footer.set_items({
		{ text = string.format("%s %d", icons.volume_icon("default"), #volumes), hl = "DockyardImage" },
	})
end

local function cell_hl(_, col)
	if col.key == "name" then
		return "DockyardName"
	end
	if col.key == "driver" then
		return "DockyardImage"
	end
	if col.key == "scope" then
		return "DockyardPorts"
	end
	return "DockyardMuted"
end

---@param width number
---@param volumes Volume[]
---@return string[] lines, table line_map, table spans
local function build_body(width, volumes)
	view_state.last_rendered_at = vim.loop.hrtime()
	local rows = build_rows(volumes)

	local lines, line_map, spans = table_view.render({
		width = width,
		margin = 1,
		columns = {
			{ key = "name", name = "Volume", min_width = 30 },
			{ key = "driver", name = "Driver", min_width = 10 },
			{ key = "scope", name = "Scope", min_width = 10 },
			{ key = "mountpoint", name = "Mountpoint", min_width = 20 },
		},
		rows = rows,
		cell_hl = cell_hl,
	})

	for lnum, node in pairs(line_map) do
		if node and node.kind == "volume" then
			local line = lines[lnum] or ""
			local volume_icon = icons.volume_icon("default")
			local s = line:find(volume_icon, 1, true)
			if s then
				table.insert(spans, {
					line = lnum - 1,
					start_col = s - 1,
					end_col = s - 1 + #volume_icon,
					hl_group = "DockyardImage",
				})
			end
		end
	end

	return lines, line_map, spans
end

function M.render()
	local buf = ui_state.buf_id
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local lines = {}
	local spans = {}
	local width = current_width()
	local volumes = data_state.volumes.get_items()

	ui_utils.append_block(lines, spans, header.render(ui_state.mode, width))

	local views = config.options.display.views or { "containers", "images", "networks", "volumes" }
	ui_utils.append_block(
		lines,
		spans,
		navbar.render({
			width = width,
			current_view = ui_state.current_view,
			views = views,
		})
	)
	table.insert(lines, "")

	local ok, body_lines, body_line_map, body_spans = pcall(build_body, width, volumes)
	if not ok then
		local msg = "Dockyard render error: " .. tostring(body_lines)
		vim.notify(msg, vim.log.levels.ERROR)
		body_lines = { msg }
		body_line_map = {}
		body_spans = {
			{ line = 0, start_col = 0, end_col = #msg, hl_group = "DockyardStopped" },
		}
	end

	local body_start = ui_utils.append_body(lines, spans, body_lines, body_spans)
	ui_state.line_map = {}
	for lnum, item in pairs(body_line_map or {}) do
		ui_state.line_map[body_start + lnum] = item
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	ui_utils.apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	set_footer_items(volumes)
end

return M
