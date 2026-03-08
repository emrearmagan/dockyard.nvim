local M = {}

local state = require("dockyard.ui.state")
local config = require("dockyard.config")

local header = require("dockyard.ui.components.header")
local navbar = require("dockyard.ui.components.navbar")
local containers_view = require("dockyard.ui.views.containers")
local images_view = require("dockyard.ui.views.images")

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

local function append_body(lines, spans, body_lines, body_spans)
	local body_start = #lines

	for _, line in ipairs(body_lines or {}) do
		table.insert(lines, line)
	end

	for _, span in ipairs(body_spans or {}) do
		table.insert(spans, {
			line = body_start + span.line,
			start_col = span.start_col,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end

	return body_start
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

	local body_lines, body_line_map, body_spans
	if state.current_view == "containers" then
		local ok
		ok, body_lines, body_line_map, body_spans = pcall(containers_view.render, width)
		if not ok then
			local msg = "Dockyard render error: " .. tostring(body_lines)
			vim.notify(msg, vim.log.levels.ERROR)
			body_lines = { msg }
			body_line_map = {}
			body_spans = {
				{ line = 0, start_col = 0, end_col = #msg, hl_group = "DockyardStopped" },
			}
		end
	elseif state.current_view == "images" then
		local ok
		ok, body_lines, body_line_map, body_spans = pcall(images_view.render, width)
		if not ok then
			local msg = "Dockyard render error: " .. tostring(body_lines)
			vim.notify(msg, vim.log.levels.ERROR)
			body_lines = { msg }
			body_line_map = {}
			body_spans = {
				{ line = 0, start_col = 0, end_col = #msg, hl_group = "DockyardStopped" },
			}
		end
	else
		local body_line = string.format("View: %s (coming next phase)", state.current_view)
		body_lines = { body_line }
		body_line_map = {}
		body_spans = {
			{ line = 0, start_col = 0, end_col = #body_line, hl_group = "DockyardDim" },
		}
	end

	local body_start = append_body(lines, spans, body_lines, body_spans)
	state.line_map = {}
	for lnum, item in pairs(body_line_map or {}) do
		state.line_map[body_start + lnum] = item
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
