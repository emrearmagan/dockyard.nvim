local M = {}

local ui_state = require("dockyard.ui.state")
local spinner = require("dockyard.ui.components.spinner")
local icons = require("dockyard.ui.icons")

local ns = vim.api.nvim_create_namespace("dockyard.footer")

---@alias DockyardFooterAlign "left"|"right"

---@class DockyardFooterItem
---@field text string
---@field hl string
---@field alignment DockyardFooterAlign|nil

---@class DockyardFooterNotice
---@field text string
---@field hl_group string
---@field token integer

---@type DockyardFooterNotice
local notice = {
	text = "",
	hl_group = "DockyardMuted",
	token = 0,
}

---@class DockyardFooterLoading
---@field spinner SpinnerInstance|nil
---@field text string

---@type DockyardFooterLoading
local loading = {
	spinner = nil,
	text = "",
}

---@type DockyardFooterItem[]
local items = {}

---@param text string|nil
---@return number
local function text_width(text)
	return vim.fn.strdisplaywidth(text or "")
end

---@param text string|nil
---@return string
local function sanitize_notice_text(text)
	local msg = tostring(text or ""):gsub("[\r\n]+", " | ")
	if #msg > 70 then
		msg = msg:sub(1, 67) .. "..."
	end
	return msg
end

local NOTICE_HL = {
	success = "DockyardRunning",
	warn = "DockyardPaused",
	error = "DockyardStopped",
	info = "DockyardName",
	loading = "DockyardName",
}

local NOTICE_ICON = {
	success = icons.icon("success"),
	warn = icons.icon("warning"),
	error = icons.icon("error"),
	info = icons.icon("info"),
	loading = "",
}

local function stop_loading()
	if loading.spinner ~= nil then
		loading.spinner:stop()
		loading.spinner = nil
	end
end

---@param token integer
local function start_loading(token)
	if loading.spinner ~= nil then
		return
	end

	loading.spinner = spinner.create({
		interval_ms = 120,
		on_tick = function(frame)
			if notice.token ~= token then
				stop_loading()
				return
			end
			notice.text = string.format("%s %s", frame, loading.text)
			M.refresh()
		end,
	})

	loading.spinner:start()
end

---@return table[]
local function segments_for()
	local left = vim.deepcopy(items)

	local right = {
		{ text = notice.text ~= "" and notice.text or "", hl = notice.text ~= "" and notice.hl_group or "DockyardMuted", alignment = "right" },
		{ text = "dockyard", hl = "DockyardName", alignment = "right" },
		{ text = "? help", hl = "DockyardHelpKey", alignment = "right" },
	}

	for _, seg in ipairs(right) do
		table.insert(left, seg)
	end

	return left
end

---Replace footer left-side items.
---@param new_items DockyardFooterItem[]|nil
function M.set_items(new_items)
	items = vim.deepcopy(new_items or {})
	M.refresh()
end

function M.clear_items()
	items = {}
	M.refresh()
end

---@param segments table[]
---@param width integer
---@return string
---@return table[]
local function render_line(segments, width)
	local left_segments, right_segments = {}, {}
	for _, seg in ipairs(segments or {}) do
		if seg.alignment == "right" then
			table.insert(right_segments, seg)
		else
			table.insert(left_segments, seg)
		end
	end

	local function build_line(parts)
		local line = ""
		local spans = {}
		local col = 0
		for _, seg in ipairs(parts) do
			local normalized = vim.trim(tostring(seg.text or ""))
			local text = normalized == "" and "" or (" " .. normalized .. " ")
			line = line .. text
			if seg.hl ~= nil and text ~= "" then
				table.insert(spans, {
					line = 0,
					start_col = col,
					end_col = col + #text,
					hl_group = seg.hl,
				})
			end
			col = col + #text
		end
		return line, spans
	end

	local left_line, left_hls = build_line(left_segments)
	local right_line, right_hls = build_line(right_segments)
	local max_left = math.max(width - text_width(right_line) - 1, 0)

	if text_width(left_line) > max_left then
		local fitted = {}
		local used = 0
		for _, seg in ipairs(left_segments) do
			local normalized = vim.trim(tostring(seg.text or ""))
			local text = normalized == "" and "" or (" " .. normalized .. " ")
			local seg_w = text_width(text)
			if used + seg_w > max_left then
				break
			end
			table.insert(fitted, seg)
			used = used + seg_w
		end
		left_line, left_hls = build_line(fitted)
	end

	local gap = width - text_width(left_line) - text_width(right_line)
	if gap < 1 then
		gap = 1
	end

	local line = left_line .. string.rep(" ", gap) .. right_line
	if text_width(line) < width then
		line = line .. string.rep(" ", width - text_width(line))
	end

	local highlights = {
		{ line = 0, start_col = 0, end_col = math.max(width, 1), hl_group = "DockyardFooterBackground" },
	}

	for _, hl in ipairs(left_hls) do
		table.insert(highlights, hl)
	end

	local right_offset = #left_line + gap
	for _, hl in ipairs(right_hls) do
		table.insert(highlights, {
			line = 0,
			start_col = hl.start_col + right_offset,
			end_col = hl.end_col + right_offset,
			hl_group = hl.hl_group,
		})
	end

	return line, highlights
end

---@param level "success"|"warn"|"error"|"info"|"loading"
---@param text string
---@param duration_ms number|nil
function M.notify(level, text, duration_ms)
	local message = sanitize_notice_text(text)
	notice.token = notice.token + 1
	local token = notice.token

	stop_loading()

	if level == "loading" then
		notice.hl_group = NOTICE_HL.info or "DockyardMuted"
		loading.text = message
		start_loading(token)
		notice.text = loading.spinner ~= nil and loading.spinner:text(loading.text) or loading.text
		M.refresh()
		return
	end

	local icon = NOTICE_ICON[level] or ""
	notice.text = icon ~= "" and string.format("%s %s", icon, message) or message
	notice.hl_group = NOTICE_HL[level] or "DockyardMuted"
	M.refresh()

	vim.defer_fn(function()
		if notice.token ~= token then
			return
		end
		notice.text = ""
		notice.hl_group = "DockyardMuted"
		M.refresh()
	end, duration_ms or 2500)
end

function M.refresh()
	local win = ui_state.footer_win_id
	local buf = ui_state.footer_buf_id
	if win == nil or not vim.api.nvim_win_is_valid(win) then
		return
	end
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local width = vim.api.nvim_win_get_width(win)
	local line, highlights = render_line(segments_for(), width)

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(highlights) do
		vim.api.nvim_buf_set_extmark(buf, ns, span.line, span.start_col, {
			end_row = span.line,
			end_col = span.end_col,
			hl_group = span.hl_group,
		})
	end
end

return M
