local M = {}

local panel_state = require("dockyard.ui.panel.state")
local chips = require("dockyard.ui.panel.components.chips")
local tabs = require("dockyard.ui.panel.components.tabs")
local docker = require("dockyard.docker")

local TABS = {
	{ key = "config", label = "Configuration" },
}

local state = {
	current_tab = nil,
	inspect_id = nil,
	inspect_data = nil,
	inspect_loading = false,
}

---@return string
function M.get_tab()
	if not state.current_tab then
		state.current_tab = TABS[1].key
	end
	return state.current_tab
end

function M.set_tab(key)
	state.current_tab = key
end

local function ensure_inspect(network_id)
	if state.inspect_id == network_id then
		return state.inspect_data
	end

	if state.inspect_loading then
		return nil
	end

	state.inspect_id = network_id
	state.inspect_data = nil
	state.inspect_loading = true

	local requested_id = network_id
	docker.inspect("network", network_id, function(result)
		if state.inspect_id ~= requested_id then
			return
		end
		state.inspect_loading = false
		if result.ok and result.data then
			state.inspect_data = result.data
			local panel = require("dockyard.ui.panel")
			panel.render()
		end
	end)

	return nil
end

local function append_detail_section(lines, spans, title, rows, margin)
	local pad = string.rep(" ", margin)

	table.insert(lines, pad .. title)
	table.insert(spans, {
		line = #lines - 1,
		start_col = margin,
		end_col = margin + #title,
		hl_group = "DockyardColumnHeader",
	})

	for _, row in ipairs(rows) do
		local label = row[1]
		local value = tostring(row[2] or "-")
		local value_hl = row[3]

		local label_pad = pad .. "  "
		local label_str = label_pad .. label
		local gap = math.max(16 - #label, 2)
		local line = label_str .. string.rep(" ", gap) .. value
		table.insert(lines, line)

		table.insert(spans, {
			line = #lines - 1,
			start_col = #label_pad,
			end_col = #label_pad + #label,
			hl_group = "DockyardMuted",
		})

		if value_hl then
			local val_start = #label_str + gap
			table.insert(spans, {
				line = #lines - 1,
				start_col = val_start,
				end_col = val_start + #value,
				hl_group = value_hl,
			})
		end
	end
end

local function render_config(data, width)
	local lines = {}
	local spans = {}

	local created = type(data.Created) == "string" and data.Created:sub(1, 19):gsub("T", " ") or "-"
	local containers = type(data.Containers) == "table" and data.Containers or {}
	local container_count = vim.tbl_count(containers)

	append_detail_section(lines, spans, "General", {
		{ "Driver", data.Driver or "-" },
		{ "Scope", data.Scope or "-" },
		{ "Created", created },
		{ "Internal", tostring(data.Internal or false) },
		{ "Attachable", tostring(data.Attachable or false) },
		{ "Ingress", tostring(data.Ingress or false) },
		{ "Enable IPv6", tostring(data.EnableIPv6 or false) },
		{ "Containers", tostring(container_count) },
	}, 1)

	if container_count > 0 then
		table.insert(lines, "")
		local ctr_rows = {}
		for _, c in pairs(containers) do
			local name = type(c.Name) == "string" and c.Name or "-"
			local ip = type(c.IPv4Address) == "string" and c.IPv4Address or "-"
			table.insert(ctr_rows, { name, ip })
		end
		table.sort(ctr_rows, function(a, b)
			return a[1] < b[1]
		end)
		append_detail_section(lines, spans, "Attached Containers", ctr_rows, 1)
	end

	local ipam = data.IPAM or {}
	local ipam_configs = ipam.Config or {}
	local ipam_config = ipam_configs[1] or {}

	table.insert(lines, "")

	append_detail_section(lines, spans, "IPAM", {
		{ "Driver", ipam.Driver or "-" },
		{ "Subnet", ipam_config.Subnet or "-" },
		{ "Gateway", ipam_config.Gateway or "-" },
	}, 1)

	local options = type(data.Options) == "table" and data.Options or {}
	if next(options) then
		table.insert(lines, "")
		local opt_rows = {}
		for k, v in pairs(options) do
			table.insert(opt_rows, { k, v })
		end
		table.sort(opt_rows, function(a, b)
			return a[1] < b[1]
		end)
		append_detail_section(lines, spans, "Options", opt_rows, 1)
	end

	return lines, spans
end

function M.tabs()
	return TABS
end

---@param width number
---@return string[] lines, table[] spans
function M.render(width)
	local node = panel_state.current_node
	if not node or node.kind ~= "network" then
		return {}, {}
	end

	local active_tab = M.get_tab()

	local lines = {}
	local spans = {}

	-- Chips
	local item = node and node.item
	if item then
		local chip_items = {
			{ text = string.format("Driver: %s", item.driver or "-"), hl_group = "DockyardImage" },
			{ text = string.format("Scope: %s", item.scope or "-"), hl_group = "DockyardPorts" },
		}
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

	-- Content
	local content_lines, content_spans = {}, {}
	if item then
		local data = ensure_inspect(item.id)
		if not data then
			content_lines = { "", "  Loading..." }
			content_spans = { { line = 1, start_col = 2, end_col = #content_lines[2], hl_group = "DockyardMuted" } }
		elseif active_tab == "config" then
			content_lines, content_spans = render_config(data, width)
		end
	end

	local body_start = #lines
	for _, l in ipairs(content_lines) do
		table.insert(lines, l)
	end
	for _, s in ipairs(content_spans) do
		s.line = s.line + body_start
		table.insert(spans, s)
	end

	return lines, spans
end

return M
