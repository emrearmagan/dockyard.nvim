local M = {}

local panel_state = require("dockyard.ui.panel.state")
local generic_popup = require("dockyard.ui.popups.popup")

local ns = vim.api.nvim_create_namespace("dockyard.panel")

local CONTROLLERS = {
	container = require("dockyard.ui.panel.controllers.container"),
	image = require("dockyard.ui.panel.controllers.image"),
	network = require("dockyard.ui.panel.controllers.network"),
	volume = require("dockyard.ui.panel.controllers.volume"),
}

local popup = nil
local mapped_buf = nil

---@param kind "container"|"image"|"network"|"volume"
---@return table|nil
local function get_controller(kind)
	local mod = CONTROLLERS[kind]
	if not mod then
		return nil
	end

	return mod
end

local function get_active_controller()
	if not panel_state.current_node then
		return nil
	end

	return get_controller(panel_state.current_node.kind)
end

local function ensure_popup()
	if popup then
		return popup
	end

	popup = generic_popup.create({
		title = " Detail ",
		view = "panel",
		on_resize = function()
			M.render()
		end,
		on_close = function()
			local ctrl = get_active_controller()
			if ctrl and type(ctrl.on_close) == "function" then
				ctrl.on_close()
			end
			panel_state.reset()
			mapped_buf = nil
		end,
	})

	return popup
end

local function register_panel_keys(buf)
	if mapped_buf == buf then
		return
	end

	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "<Tab>", function()
		M.next_tab()
	end, opts)

	vim.keymap.set("n", "<S-Tab>", function()
		M.prev_tab()
	end, opts)

	vim.keymap.set("n", "]", function()
		M.next_tab()
	end, opts)

	vim.keymap.set("n", "[", function()
		M.prev_tab()
	end, opts)

	mapped_buf = buf
end

---@param node table|nil
function M.open(node)
	if not node or not node.item then
		--- TODO: Pass notify function like the rest of the code
		vim.notify("Dockyard: no item selected", vim.log.levels.WARN)
		return
	end

	local ctrl = get_controller(node.kind)
	if not ctrl then
		vim.notify("Dockyard: no detail panel for " .. tostring(node.kind), vim.log.levels.Error)
		return
	end

	local p = ensure_popup()
	panel_state.set_current(node)

	local kind_label = (node.kind or ""):sub(1, 1):upper() .. (node.kind or ""):sub(2)
	local item_name = node.item.name or node.item.repository or node.item.id or "-"
	local title = string.format(" %s: %s ", kind_label, item_name)

	local _, buf = p.open({
		title = title,
		footer = " Tab/S-Tab: switch tabs ",
		view = "panel",
	})

	register_panel_keys(buf)

	M.render()
end

function M.next_tab()
	local ctrl = get_active_controller()
	if not ctrl then
		return
	end

	local tab_list = ctrl.tabs()
	local idx = 1
	for i, tab in ipairs(tab_list) do
		if tab.key == ctrl.get_tab() then
			idx = i
			break
		end
	end

	local next_idx = (idx % #tab_list) + 1
	ctrl.set_tab(tab_list[next_idx].key)
	M.render()
end

function M.prev_tab()
	local ctrl = get_active_controller()
	if not ctrl then
		return
	end

	local tab_list = ctrl.tabs()
	local idx = 1
	for i, tab in ipairs(tab_list) do
		if tab.key == ctrl.get_tab() then
			idx = i
			break
		end
	end

	local prev_idx = ((idx - 2) % #tab_list) + 1
	ctrl.set_tab(tab_list[prev_idx].key)
	M.render()
end

function M.render()
	if not popup or not popup.is_open() then
		return
	end

	local buf = popup.get_buf()
	local win = popup.get_win()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local width = vim.api.nvim_win_get_width(win)
	local lines = {}
	local spans = {}

	if not panel_state.current_node then
		lines = { "", "  Nothing selected..." }
	else
		local ctrl = get_active_controller()
		if ctrl and type(ctrl.render) == "function" then
			lines, spans = ctrl.render(width)
		else
			lines = { "", "Uuups....: " .. tostring(panel_state.current_node.kind) }
		end
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, span in ipairs(spans or {}) do
		if
			type(span) == "table"
			and span.line ~= nil
			and span.start_col ~= nil
			and span.end_col ~= nil
			and span.hl_group ~= nil
		then
			local line_text = vim.api.nvim_buf_get_lines(buf, span.line, span.line + 1, false)[1] or ""
			local end_col = math.min(span.end_col, #line_text)
			local start_col = math.min(span.start_col, end_col)
			if end_col > start_col then
				vim.api.nvim_buf_set_extmark(buf, ns, span.line, start_col, {
					end_row = span.line,
					end_col = end_col,
					hl_group = span.hl_group,
				})
			end
		end
	end
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
