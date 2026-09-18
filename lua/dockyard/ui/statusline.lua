local M = {}

local icons = require("dockyard.ui.icons")
local keymaps = require("dockyard.core.keymaps")
local spinner = require("dockyard.ui.components.spinner")

local BACKGROUND_HL = "DockyardFooterBackground"
local EXPRESSION = "%!v:lua.require'dockyard.ui.statusline'.current()"

---@class DockyardStatuslineSegment
---@field text string
---@field hl_group string|nil
---@field align "right"|nil

---@class DockyardStatuslineNotice
---@field text string
---@field hl_group string

---@class DockyardStatuslineNoticeState: DockyardStatuslineNotice
---@field token integer

---@type DockyardStatuslineSegment[]
local items = {}

---@type DockyardStatuslineNoticeState
local notice = {
	text = "",
	hl_group = "DockyardFooterText",
	token = 0,
}

---@type SpinnerInstance|nil
local loading_spinner

---@type string|nil
local cached_version

local function redraw()
	vim.cmd("redrawstatus")
end

---@param text any
---@return string
local function normalize(text)
	return tostring(text or ""):gsub("[\r\n]+", " | "):match("^%s*(.-)%s*$") or ""
end

---@param text string
---@param max_width integer
---@return string
local function truncate(text, max_width)
	if max_width < 1 then
		return ""
	end
	if vim.api.nvim_strwidth(text) <= max_width then
		return text
	end

	local marker = max_width < 3 and string.rep(".", max_width) or "..."
	local available = max_width - vim.api.nvim_strwidth(marker)
	for chars = vim.fn.strchars(text) - 1, 0, -1 do
		local head = vim.fn.strcharpart(text, 0, chars)
		if vim.api.nvim_strwidth(head) <= available then
			return head .. marker
		end
	end
	return marker
end

---@param segment DockyardStatuslineSegment
---@return DockyardStatuslineSegment
local function copy_segment(segment)
	return {
		text = normalize(segment.text),
		hl_group = segment.hl_group,
		align = segment.align,
	}
end

---@param segment DockyardStatuslineSegment
---@return integer
local function segment_width(segment)
	return segment.text == "" and 0 or vim.api.nvim_strwidth(segment.text) + 1
end

---@return integer
local function current_width()
	local win = tonumber(vim.g.statusline_winid)
	if vim.o.laststatus == 3 or not win then
		return vim.o.columns
	end
	return vim.api.nvim_win_get_width(win)
end

---@param segment DockyardStatuslineSegment
---@return string
local function render_segment(segment)
	if segment.text == "" then
		return ""
	end

	local text = segment.text:gsub("%%", "%%%%")
	return string.format("%%#%s# %s%%#%s#", segment.hl_group or "DockyardFooterText", text, BACKGROUND_HL)
end

---@param output string[]
---@param segment DockyardStatuslineSegment
local function add(output, segment)
	local rendered = render_segment(segment)
	if rendered ~= "" then
		output[#output + 1] = rendered
	end
end

---@return string|nil
local function help_label()
	local keys = keymaps.resolve("ui.help")
	return keys and string.format("%s help", keys[1]) or nil
end

---@return string
local function version()
	if cached_version then
		return cached_version
	end

	local source = debug.getinfo(1, "S").source
	if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
		cached_version = "dev"
		return cached_version
	end

	local directory = vim.fn.fnamemodify(source:sub(2), ":h")
	local result = vim.fn.system({ "git", "-C", directory, "describe", "--tags", "--abbrev=0" })
	if vim.v.shell_error == 0 and type(result) == "string" and vim.trim(result) ~= "" then
		cached_version = vim.trim(result)
	else
		cached_version = "dev"
	end
	return cached_version
end

---@param segments DockyardStatuslineSegment[]
---@param current_notice DockyardStatuslineNotice|nil
---@param available integer|nil
---@return string
function M.format(segments, current_notice, available)
	local left, right = {}, {}
	local remaining = available or current_width()
	for _, segment in ipairs(segments or {}) do
		local normalized = copy_segment(segment)
		add(normalized.align == "right" and right or left, normalized)
		remaining = remaining - segment_width(normalized)
	end
	if current_notice then
		local notice_segment = {
			text = normalize(current_notice.text),
			hl_group = current_notice.hl_group,
		}
		add(right, notice_segment)
		remaining = remaining - segment_width(notice_segment)
	end
	local version_segment = {
		text = string.format("dockyard (%s)", version()),
		hl_group = "DockyardFooterText",
	}
	local help_segment = {
		text = help_label() or "",
		hl_group = "DockyardFooterHelp",
	}

	-- Hide the version first, then help, when space runs out.
	local help_width = segment_width(help_segment)
	if segment_width(version_segment) + help_width <= remaining then
		add(right, version_segment)
	end
	if help_width <= remaining then
		add(right, help_segment)
	end

	return table.concat({
		"%#" .. BACKGROUND_HL .. "#%<",
		table.concat(left),
		"%=",
		table.concat(right),
	})
end

local function stop_loading()
	if loading_spinner then
		loading_spinner:stop()
		loading_spinner = nil
	end
end

---@param token integer
---@param message string
local function start_loading(token, message)
	loading_spinner = spinner.create({
		interval_ms = 120,
		on_tick = function(frame)
			if notice.token ~= token then
				return
			end

			notice.text = string.format("%s %s", frame, message)
			redraw()
		end,
	})
	loading_spinner:start()
end

---@param level "success"|"warn"|"error"|"info"|"loading"
---@return string icon
---@return string hl_group
local function notice_style(level)
	if level == "loading" then
		return "", "DockyardFooterInfo"
	end

	local highlights = {
		success = "DockyardFooterSuccess",
		warn = "DockyardFooterWarning",
		error = "DockyardFooterError",
		info = "DockyardFooterInfo",
	}
	return icons.icon(level), highlights[level] or "DockyardFooterText"
end

---@param win any
---@return boolean
local function valid_window(win)
	if type(win) ~= "number" then
		return false
	end

	local ok, valid = pcall(vim.api.nvim_win_is_valid, win)
	return ok and valid
end

---@param win integer
---@return boolean
function M.is_attached(win)
	if not valid_window(win) then
		return false
	end

	local ok, value = pcall(vim.api.nvim_get_option_value, "statusline", { win = win, scope = "local" })
	return ok and value == EXPRESSION
end

---@param target_win integer
---@param source_win integer
---@return boolean inherited
function M.inherit(target_win, source_win)
	if vim.o.laststatus ~= 3 or not valid_window(target_win) or not valid_window(source_win) then
		return false
	end

	local ok, value = pcall(vim.api.nvim_get_option_value, "statusline", { win = source_win, scope = "local" })
	if not ok or value ~= EXPRESSION then
		return false
	end

	local set_ok = pcall(vim.api.nvim_set_option_value, "statusline", value, { win = target_win, scope = "local" })
	return set_ok
end

---@param win integer
function M.attach(win)
	vim.api.nvim_set_option_value("statusline", EXPRESSION, { win = win, scope = "local" })
end

function M.clear_items()
	items = {}
	redraw()
end

---@param new_items DockyardStatuslineSegment[]|nil
function M.set_items(new_items)
	items = vim.deepcopy(new_items or {})
	redraw()
end

---@param level "success"|"warn"|"error"|"info"|"loading"
---@param text string
---@param duration_ms number|nil
function M.notify(level, text, duration_ms)
	local message = truncate(normalize(text), 70)
	notice.token = notice.token + 1
	local token = notice.token
	stop_loading()

	local icon, hl_group = notice_style(level)
	notice.hl_group = hl_group
	if level == "loading" then
		start_loading(token, message)
		notice.text = loading_spinner and loading_spinner:text(message) or message
		redraw()
		return
	end

	notice.text = icon ~= "" and string.format("%s %s", icon, message) or message
	redraw()
	vim.defer_fn(function()
		if notice.token ~= token then
			return
		end
		notice.text = ""
		notice.hl_group = "DockyardFooterText"
		redraw()
	end, duration_ms or 2500)
end

---@return string
function M.current()
	return M.format(items, notice)
end

function M.clear_notice()
	notice.token = notice.token + 1
	stop_loading()
	notice.text = ""
	notice.hl_group = "DockyardFooterText"
	redraw()
end

function M.reset()
	items = {}
	M.clear_notice()
end

return M
