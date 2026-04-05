local M = {}
local icons = require("dockyard.ui.icons")

local function text_width(text)
	return vim.fn.strdisplaywidth(text)
end

local function title_case(value)
	if value == nil or value == "" then
		return ""
	end
	return value:sub(1, 1):upper() .. value:sub(2)
end

---@param opts { current_view: string, views: string[], width: number }
---@return { lines: string[], highlights: table[] }
function M.render(opts)
	local width = opts.width or vim.o.columns
	local current_view = opts.current_view
	local views = opts.views or { "containers", "images", "networks" }

	local actions = {
		{ label = " Refresh (R) ", hl = "DockyardActionRefresh" },
		{ label = " Help (?) ", hl = "DockyardActionHelp" },
	}

	local margin = 2
	local line = string.rep(" ", margin)
	local highlights = {}
	local current_byte_pos = margin
	local current_display_pos = margin

	for _, view in ipairs(views) do
		local label = string.format(" %s  %s ", icons.view_icon(view), title_case(view))
		local is_active = view == current_view
		local hl_group = is_active and "DockyardTabActive" or "DockyardTabInactive"

		line = line .. label .. "  "
		table.insert(highlights, {
			line = 0,
			start_col = current_byte_pos,
			end_col = current_byte_pos + #label,
			hl_group = hl_group,
		})

		current_byte_pos = current_byte_pos + #label + 2
		current_display_pos = current_display_pos + text_width(label) + 2
	end

	local actions_total_w = 0
	for i, action in ipairs(actions) do
		actions_total_w = actions_total_w + text_width(action.label)
		if i < #actions then
			actions_total_w = actions_total_w + 2
		end
	end

	local padding = width - current_display_pos - actions_total_w - margin
	if padding > 0 then
		line = line .. string.rep(" ", padding)
		current_byte_pos = current_byte_pos + padding
	end

	for i, action in ipairs(actions) do
		line = line .. action.label
		table.insert(highlights, {
			line = 0,
			start_col = current_byte_pos,
			end_col = current_byte_pos + #action.label,
			hl_group = action.hl,
		})

		current_byte_pos = current_byte_pos + #action.label
		if i < #actions then
			line = line .. "  "
			current_byte_pos = current_byte_pos + 2
		end
	end

	return {
		lines = { line },
		highlights = highlights,
	}
end

return M
