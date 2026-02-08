local TableRenderer = require("dockyard.ui.table")

local M = {}

local MARGIN = 2

local function text_width(text)
	return TableRenderer.text_width(text)
end

function M.render(ctx)
	local width = ctx.width
	local current_view = ctx.current_view
	local lines = {}
	local highlights = {}

	-- Left items (Tabs)
	local tabs = {
		{ id = "containers", label = "   Containers " },
		{ id = "images", label = " 󰏗  Images " },
		{ id = "networks", label = " 󱂇  Networks " },
	}

	-- Right items (Actions)
	local actions = {
		{ key = "R", label = " Refresh (R) ", hl = "DockyardActionRefresh" },
		{ key = "?", label = " Help (?) ", hl = "DockyardActionHelp" },
	}

	local line = string.rep(" ", MARGIN)
	local current_byte_pos = MARGIN
	local current_display_pos = MARGIN

	-- Render Tabs (Left aligned)
	for _, tab in ipairs(tabs) do
		local label = tab.label
		local is_active = tab.id == current_view
		local hl_group = is_active and "DockyardTabActive" or "DockyardTabInactive"
		
		line = line .. label .. "  "
		highlights[#highlights + 1] = {
			line = 0,
			col_start = current_byte_pos,
			col_end = current_byte_pos + #label,
			group = hl_group,
		}
		current_byte_pos = current_byte_pos + #label + 2
		current_display_pos = current_display_pos + text_width(label) + 2
	end

	-- Calculate total width of actions
	local actions_total_w = 0
	for i, action in ipairs(actions) do
		actions_total_w = actions_total_w + text_width(action.label)
		if i < #actions then
			actions_total_w = actions_total_w + 2 -- space between actions
		end
	end

	-- Calculate padding to right-align actions
	-- Subtracting MARGIN from the right as well
	local padding = width - current_display_pos - actions_total_w - MARGIN
	if padding > 0 then
		line = line .. string.rep(" ", padding)
		current_byte_pos = current_byte_pos + padding
		current_display_pos = current_display_pos + padding
	end

	-- Render Actions
	for i, action in ipairs(actions) do
		local label = action.label
		line = line .. label
		highlights[#highlights + 1] = {
			line = 0,
			col_start = current_byte_pos,
			col_end = current_byte_pos + #label,
			group = action.hl or "DockyardAction",
		}
		current_byte_pos = current_byte_pos + #label
		current_display_pos = current_display_pos + text_width(label)
		
		if i < #actions then
			line = line .. "  "
			current_byte_pos = current_byte_pos + 2
			current_display_pos = current_display_pos + 2
		end
	end

	lines[#lines + 1] = line
	return lines, highlights
end

return M
