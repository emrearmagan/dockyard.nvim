local TableRenderer = require("dockyard.ui.table")
local state = require("dockyard.ui.state")
local colors = require("dockyard.ui.colors")

local M = {}

local namespace = vim.api.nvim_create_namespace("dockyard_ui")
local MARGIN = 2

function M.ensure_hl_groups()
	local c = colors.groups

	vim.api.nvim_set_hl(0, "DockyardHeader", { bg = c.header_bg, fg = c.header_fg, bold = true })
	vim.api.nvim_set_hl(0, "DockyardName", { fg = c.name })
	vim.api.nvim_set_hl(0, "DockyardImage", { fg = c.image })
	vim.api.nvim_set_hl(0, "DockyardPorts", { fg = c.ports })
	vim.api.nvim_set_hl(0, "DockyardMuted", { fg = c.muted })
	
	-- Navbar Highlights
	vim.api.nvim_set_hl(0, "DockyardTabActive", { bg = c.tab_active_bg, fg = c.tab_active_fg, bold = true })
	vim.api.nvim_set_hl(0, "DockyardTabInactive", { bg = c.tab_inactive_bg, fg = c.tab_inactive_fg })
	vim.api.nvim_set_hl(0, "DockyardAction", { bg = c.action_bg, fg = c.action_fg })
	vim.api.nvim_set_hl(0, "DockyardActionRefresh", { bg = c.action_refresh_fg, fg = c.tab_active_fg, bold = true })
	vim.api.nvim_set_hl(0, "DockyardActionHelp", { bg = c.action_help_fg, fg = c.tab_active_fg, bold = true })

	vim.api.nvim_set_hl(0, "DockyardColumnHeader", { fg = c.column_header, bold = true })
	vim.api.nvim_set_hl(0, "DockyardCursorLine", { bg = c.cursor_line })
	vim.api.nvim_set_hl(0, "DockyardStatusRunning", { fg = c.status_running, bold = true })
	vim.api.nvim_set_hl(0, "DockyardStatusStopped", { fg = c.status_stopped, bold = true })

	-- Help highlights
	vim.api.nvim_set_hl(0, "DockyardHelpKey", { fg = c.help_key, bold = true })
	vim.api.nvim_set_hl(0, "DockyardHelpDesc", { fg = c.help_desc })
end

function M.draw()
	local win_width = vim.api.nvim_win_get_width(state.win)
	local final_lines = {}
	local final_highlights = {}

	-- 1. Header
	local title = "    Docker  "
	local title_w = TableRenderer.text_width(title)
	local title_padding = math.floor((win_width - title_w) / 2)
	final_lines[#final_lines + 1] = string.rep(" ", title_padding) .. title
	final_highlights[#final_highlights + 1] = {
		line = #final_lines - 1,
		col_start = title_padding,
		col_end = title_padding + #title,
		group = "DockyardHeader",
	}
	final_lines[#final_lines + 1] = ""

	-- 2. Navbar
	local navbar = require("dockyard.ui.components.navbar")
	local nav_lines, nav_hls = navbar.render({
		width = win_width,
		current_view = state.current_view,
	})
	local nav_start_line = #final_lines
	for _, line in ipairs(nav_lines) do
		final_lines[#final_lines + 1] = line
	end
	for _, hl in ipairs(nav_hls) do
		hl.line = hl.line + nav_start_line
		final_highlights[#final_highlights + 1] = hl
	end
	final_lines[#final_lines + 1] = ""

	-- 3. Table Component
	local comp = require("dockyard.ui.components." .. state.current_view)
	local table_lines, table_hls = TableRenderer.render({
		config = comp.config,
		rows = comp.get_data(),
		width = win_width,
	})

	local table_start_line = #final_lines
	for _, line in ipairs(table_lines) do
		final_lines[#final_lines + 1] = line
	end
	for _, hl in ipairs(table_hls) do
		hl.line = hl.line + table_start_line
		final_highlights[#final_highlights + 1] = hl
	end

	-- Apply
	vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, final_lines)
	vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	for _, hl in ipairs(final_highlights) do
		vim.api.nvim_buf_add_highlight(state.buf, namespace, hl.group, hl.line, hl.col_start, hl.col_end)
	end

	return table_start_line, comp
end

return M
