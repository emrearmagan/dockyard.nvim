local M = {}

local data_state = require("dockyard.state")
local ui_state = require("dockyard.ui.state")
local config = require("dockyard.config")
local table_view = require("dockyard.ui.components.table")
local header = require("dockyard.ui.components.header")
local navbar = require("dockyard.ui.components.navbar")
local ui_utils = require("dockyard.ui.utils")
local highlights = require("dockyard.ui.highlights")
local view_state = require("dockyard.ui.views.networks.state")

local function current_width()
	if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
		return vim.api.nvim_win_get_width(ui_state.win_id)
	end
	return vim.o.columns
end

local function ts(x)
	local s = tostring(x or "")
	if s == "" then
		return "-"
	end

	s = s:gsub("T", " ")
	s = s:gsub("Z$", "")
	s = s:gsub("%.[0-9]+", "")
	s = s:gsub(" %+%d%d%d%d.*$", "")

	if #s >= 19 then
		return s:sub(1, 19)
	end

	return s
end

local function status_icon(status)
	if status == "running" then
		return "●"
	end
	if status == "paused" then
		return "◐"
	end
	if status == "restarting" then
		return "◍"
	end
	return "○"
end

local function network_key(net)
	if net and net.id and net.id ~= "" then
		return "net:" .. tostring(net.id)
	end
	return "net:" .. tostring((net and net.name) or "<none>")
end

local function container_on_network(container, network_name)
	local value = tostring(container.networks or "")
	if value == "" then
		return false
	end

	for name in value:gmatch("([^,]+)") do
		if vim.trim(name) == network_name then
			return true
		end
	end

	return false
end

local function containers_for_network(net, containers)
	local out = {}
	for _, c in ipairs(containers or {}) do
		if container_on_network(c, net.name) then
			table.insert(out, c)
		end
	end

	table.sort(out, function(a, b)
		return tostring(a.name or "") < tostring(b.name or "")
	end)

	return out
end

local function build_network_parent_row(net, containers)
	local key = network_key(net)
	local children_src = containers_for_network(net, containers)

	local row = {
		kind = "network",
		key = key,
		name = "󱂇 " .. (net.name or "-"),
		driver = net.driver or "-",
		scope = net.scope or "-",
		network_id = tostring(net.id or ""):sub(1, 12),
		created = ts(net.created),
		expanded = view_state.expanded[key],
		children = {},
		_item = {
			kind = "network",
			item = net,
			key = key,
		},
	}

	for _, c in ipairs(children_src) do
		table.insert(row.children, {
			kind = "container",
			name = status_icon(c.status) .. " " .. (c.name or c.id or "-"),
			driver = "",
			scope = "",
			network_id = tostring(c.id or ""):sub(1, 12),
			created = "",
			_item = {
				kind = "container",
				item = c,
				parent_network = net,
			},
		})
	end

	return row
end

local function to_tree_rows(networks, containers)
	local rows = {}
	local sorted = vim.deepcopy(networks or {})

	table.sort(sorted, function(a, b)
		return tostring(a.name or "") < tostring(b.name or "")
	end)

	for _, net in ipairs(sorted) do
		table.insert(rows, build_network_parent_row(net, containers))
	end

	return rows
end

local function cell_hl(row, col)
	if row.kind == "network" then
		if col.key == "name" then
			return "DockyardName"
		end
		if col.key == "driver" then
			return "DockyardImage"
		end
		if col.key == "scope" then
			return "DockyardPorts"
		end
		return "DockyardMuted"
	end

	if col.key == "name" then
		return "DockyardMuted"
	end
	return "DockyardMuted"
end

---@param width number
---@return string[] lines, table line_map, table spans
local function build_body(width)
	local networks = data_state.networks.get_items()
	local containers = data_state.containers.get_items()

	local rows = to_tree_rows(networks, containers)

	local lines, line_map, spans = table_view.render({
		width = width,
		margin = 1,
		columns = {
			{ key = "name", name = "Network / Container", min_width = 30 },
			{ key = "driver", name = "Driver", min_width = 14 },
			{ key = "scope", name = "Scope", min_width = 10 },
			{ key = "network_id", name = "ID", min_width = 14 },
			{ key = "created", name = "Created", min_width = 14 },
		},
		rows = rows,
		tree = {
			children_key = "children",
			expanded_field = "expanded",
			default_expanded = true,
			indent = "  ",
			show_indicator = true,
			leaf_prefix = "└─ ",
		},
		cell_hl = cell_hl,
	})

	for lnum, node in pairs(line_map) do
		if node and node.kind == "network" then
			local line = lines[lnum] or ""
			local s = line:find("󱂇", 1, true)
			if s then
				table.insert(spans, {
					line = lnum - 1,
					start_col = s - 1,
					end_col = s - 1 + #"󱂇",
					hl_group = "DockyardImage",
				})
			end
		elseif node and node.kind == "container" and node.item then
			local line = lines[lnum] or ""
			local st = node.item.status
			local icon = status_icon(st)
			local s = line:find(icon, 1, true)
			if s then
				table.insert(spans, {
					line = lnum - 1,
					start_col = s - 1,
					end_col = s - 1 + #icon,
					hl_group = highlights.status_hl(st),
				})
			end
		end
	end

	return lines, line_map, spans
end

function M.render()
	local buf = ui_state.buf_id
	if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local lines = {}
	local spans = {}
	local width = current_width()

	ui_utils.append_block(lines, spans, header.render(ui_state.mode, width))

	local views = config.options.display.views or { "containers", "images", "networks" }
	ui_utils.append_block(
		lines,
		spans,
		navbar.render({
			width = width,
			current_view = ui_state.current_view,
			views = views,
		})
	)
	table.insert(lines, "")

	local ok, body_lines, body_line_map, body_spans = pcall(build_body, width)
	if not ok then
		local msg = "Dockyard render error: " .. tostring(body_lines)
		vim.notify(msg, vim.log.levels.ERROR)
		body_lines = { msg }
		body_line_map = {}
		body_spans = {
			{ line = 0, start_col = 0, end_col = #msg, hl_group = "DockyardStopped" },
		}
	end

	local body_start = ui_utils.append_body(lines, spans, body_lines, body_spans)
	ui_state.line_map = {}
	for lnum, item in pairs(body_line_map or {}) do
		ui_state.line_map[body_start + lnum] = item
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	ui_utils.apply_spans(buf, spans)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

return M
