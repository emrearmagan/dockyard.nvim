local M = {}

local state = require("dockyard.ui.state")
local config = require("dockyard.config")

local header = require("dockyard.ui.components.header")
local navbar = require("dockyard.ui.components.navbar")

local ns = vim.api.nvim_create_namespace("dockyard.ui")

local function current_width()
	if state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id) then
		return vim.api.nvim_win_get_width(state.win_id)
	end

	return vim.o.columns
end

local function append_block(lines, spans, block)
	local base = #lines

	for _, line in ipairs(block.lines or {}) do
		table.insert(lines, line)
	end

	for _, span in ipairs(block.highlights or {}) do
		table.insert(spans, {
			line = base + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, span in ipairs(spans) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

function M.render()
	local buf = state.buf_id
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local lines = {}
	local spans = {}
	local width = current_width()

	append_block(lines, spans, header.render(state.mode, width))

	local views = config.options.display.views or { "containers", "images", "networks" }
	append_block(
		lines,
		spans,
		navbar.render({
			width = width,
			current_view = state.current_view,
			views = views,
		})
	)
	table.insert(lines, "")

	local body_line = string.format("View: %s (table disabled)", state.current_view)
	table.insert(lines, body_line)
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = #body_line,
		hl_group = "DockyardDim",
	})
	state.line_map = {}

	local was_modifiable = vim.api.nvim_get_option_value("modifiable", { buf = buf })
	if not was_modifiable then
		vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	apply_spans(buf, spans)

	if not was_modifiable then
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	end
end

return M
