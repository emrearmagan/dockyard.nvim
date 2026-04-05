local M = {}

local panel_state = require("dockyard.ui.panel.state")
local panel_header = require("dockyard.ui.panel.components.header")
local chips = require("dockyard.ui.panel.components.chips")
local tabs = require("dockyard.ui.panel.components.tabs")
local icons = require("dockyard.ui.icons")
local highlights = require("dockyard.ui.highlights")

local TABS = {
	{ key = "logs", label = "Logs" },
	{ key = "stats", label = "Stats" },
	{ key = "env", label = "Env" },
	{ key = "config", label = "Configuration" },
	{ key = "top", label = "Top" },
}

function M.tabs()
	return TABS
end

function M.default_tab()
	return "logs"
end

---@param width number
---@return string[] lines, table[] spans
function M.render(width)
	local node = panel_state.current_node
	local active_tab = panel_state.current_tab
	if active_tab == "" then
		active_tab = M.default_tab()
	end

	local lines = {}
	local spans = {}

	-- Header
	local h_lines, h_spans = panel_header.render(node, width)
	for _, l in ipairs(h_lines) do
		table.insert(lines, l)
	end
	for _, s in ipairs(h_spans) do
		table.insert(spans, s)
	end

	-- Chips
	local item = node and node.item
	if item then
		local chip_items = {
			{
				text = string.format("%s %s", icons.container_icon(item.status), (item.status or "unknown"):upper()),
				hl_group = highlights.status_hl(item.status),
			},
			{
				text = string.format("󰆼 %s", item.image or "-"),
				hl_group = "DockyardImage",
			},
		}
		if item.ports and item.ports ~= "" then
			table.insert(chip_items, {
				text = string.format("󰖩 %s", item.ports),
				hl_group = "DockyardPorts",
			})
		end

		local chip_line, chip_spans = chips.render(chip_items, width, 1)
		if chip_line ~= "" then
			table.insert(lines, chip_line)
			for _, s in ipairs(chip_spans) do
				s.line = #lines - 1
				table.insert(spans, s)
			end
		end
	end

	table.insert(lines, "")

	-- Tabs
	local tab_lines, tab_spans = tabs.render(TABS, active_tab, width, 1)
	local tab_start = #lines
	for _, l in ipairs(tab_lines) do
		table.insert(lines, l)
	end
	for _, s in ipairs(tab_spans) do
		s.line = s.line + tab_start
		table.insert(spans, s)
	end

	--TODO: Add me
	table.insert(lines, "")
	table.insert(lines, "  -- " .. active_tab .. " content placeholder --")
	table.insert(spans, {
		line = #lines - 1,
		start_col = 2,
		end_col = #lines[#lines],
		hl_group = "DockyardMuted",
	})

	return lines, spans
end

return M
