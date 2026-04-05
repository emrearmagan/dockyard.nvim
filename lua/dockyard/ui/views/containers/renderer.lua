local M = {}

local docker = require("dockyard.docker")
local state = require("dockyard.state")
local ui_state = require("dockyard.ui.state")
local config = require("dockyard.config")
local table_view = require("dockyard.ui.components.table")
local header = require("dockyard.ui.components.header")
local navbar = require("dockyard.ui.components.navbar")
local footer = require("dockyard.ui.components.footer")
local ui_utils = require("dockyard.ui.utils")
local highlights = require("dockyard.ui.highlights")
local view_state = require("dockyard.ui.views.containers.state")
local icons = require("dockyard.ui.icons")

local function current_width()
	if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
		return vim.api.nvim_win_get_width(ui_state.win_id)
	end
	return vim.o.columns
end

local function build_rows(items)
	local rows = {}
	local spinner_frame = view_state.spinner_frame
	for _, c in ipairs(items) do
		local icon = icons.container_icon(c.status)
		if spinner_frame and docker.is_transitional_status(c) then
			icon = spinner_frame
		end
		table.insert(rows, {
			icon = icon,
			name = c.name or "-",
			image = c.image or "-",
			status = c.status_message or "-",
			ports = c.ports or "-",
			created = c.created_since or "-",
			_status = c.status,
			_item = {
				kind = "container",
				item = c,
			},
		})
	end
	return rows
end

---@param items Container[]
local function set_footer_items(items)
	local stats = {
		running = 0,
		paused = 0,
		restarting = 0,
		exited = 0,
		total = #items,
	}

	for _, item in ipairs(items) do
		local status = item and item.status
		if status == "running" then
			stats.running = stats.running + 1
		elseif status == "paused" then
			stats.paused = stats.paused + 1
		elseif status == "restarting" or status == "starting" or status == "removing" then
			stats.restarting = stats.restarting + 1
		elseif status == "exited" then
			stats.exited = stats.exited + 1
		end
	end

	local segments = {}
	if stats.running > 0 then
		table.insert(
			segments,
			{
				text = string.format("%s %d", icons.container_icon("running"), stats.running),
				hl = "DockyardRunning",
			}
		)
	end
	if stats.paused > 0 then
		table.insert(
			segments,
			{ text = string.format("%s %d", icons.container_icon("paused"), stats.paused), hl = "DockyardPaused" }
		)
	end
	if stats.restarting > 0 then
		table.insert(segments, {
			text = string.format("%s %d", icons.container_icon("restarting"), stats.restarting),
			hl = "DockyardPending",
		})
	end
	if stats.exited > 0 then
		table.insert(
			segments,
			{ text = string.format("%s %d", icons.container_icon("exited"), stats.exited), hl = "DockyardStopped" }
		)
	end

	footer.set_items(segments)
end

---@param width number
---@param items Container[]
---@return string[] lines, table line_map, table spans
local function build_body(width, items)
	view_state.last_rendered_at = vim.loop.hrtime()
	local rows = build_rows(items)

	local columns = {
		{ key = "icon", name = " ", width = 2, min_width = 2, max_width = 2, gap_after = 0 },
		{ key = "name", name = "Name", min_width = 18, hl = "DockyardName" },
		{ key = "image", name = "Image", min_width = 20, hl = "DockyardImage" },
		{ key = "status", name = "Status", min_width = 14, hl = "DockyardMuted" },
		{ key = "ports", name = "Ports", min_width = 12, hl = "DockyardPorts" },
		{ key = "created", name = "Created", min_width = 10, hl = "DockyardMuted" },
	}

	local lines, line_map, spans = table_view.render({
		columns = columns,
		rows = rows,
		width = width,
		margin = 1,
		cell_hl = function(row, column)
			if column.key == "icon" then
				return highlights.status_hl(row._status)
			end
			return nil
		end,
	})

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
	local items = state.containers.get_items()

	ui_utils.append_block(lines, spans, header.render(ui_state.mode, width))

	local views = config.options.display.views or { "containers", "images", "networks" }
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

	local ok, body_lines, body_line_map, body_spans = pcall(build_body, width, items)
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
	set_footer_items(items)
end

return M
