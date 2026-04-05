local docker = require("dockyard.docker")
local table_view = require("dockyard.ui.components.table")
local generic_popup = require("dockyard.ui.popups.popup")

local M = {}

local popup = nil
local last_item = nil
local last_data = nil

local function v(x)
	if x == nil then
		return "-"
	end
	local s = tostring(x)
	if s == "" then
		return "-"
	end
	return s
end

local function ts(x)
	local s = v(x):gsub("T", " "):gsub("Z$", "")
	s = s:gsub("%.[0-9]+", "")
	if #s >= 19 then
		return s:sub(1, 19)
	end
	return s
end

local function keys(t)
	if type(t) ~= "table" then
		return {}
	end
	local out = vim.tbl_keys(t)
	table.sort(out)
	return out
end

local function append_table_rows(lines, spans, rows, width)
	local table_rows = {}
	for _, row in ipairs(rows or {}) do
		table.insert(table_rows, {
			field = tostring(row.label or "") .. ":",
			value = v(row.value),
			_label_hl = row.label_hl or "DockyardColumnHeader",
			_value_hl = row.value_hl or "DockyardName",
		})
	end

	local block_lines, _, block_spans = table_view.render({
		columns = {
			{ key = "field", name = "", width = 22, gap_after = 2 },
			{ key = "value", name = "", min_width = 20, grow_last = true },
		},
		rows = table_rows,
		width = width,
		margin = 0,
		cell_hl = function(row, column)
			if column.key == "field" then
				return row._label_hl
			end
			return row._value_hl
		end,
	})

	local base = #lines
	for i = 3, #block_lines do
		table.insert(lines, block_lines[i])
	end

	for _, span in ipairs(block_spans or {}) do
		if span.line >= 2 then
			table.insert(spans, {
				line = base + (span.line - 2),
				start_col = span.start_col,
				end_col = span.end_col,
				hl_group = span.hl_group,
			})
		end
	end
end

local function render_section(lines, spans, title)
	table.insert(lines, "")
	table.insert(lines, " " .. title .. " ")
	table.insert(spans, {
		line = #lines - 1,
		start_col = 0,
		end_col = -1,
		hl_group = "DockyardHeader",
	})
	table.insert(lines, "")
end

local function build_rows(item, data)
	local rows = {}
	local ipam = (data and data.IPAM) or {}
	local containers = (data and data.Containers) or {}

	rows.header = {
		{ label = "Name", value = item.name, value_hl = "DockyardName" },
		{ label = "Network ID", value = v(item.id):sub(1, 12), value_hl = "DockyardRunning" },
		{ label = "Driver", value = item.driver, value_hl = "DockyardImage" },
		{ label = "Scope", value = item.scope, value_hl = "DockyardPorts" },
		{ label = "Created", value = ts(item.created), value_hl = "DockyardMuted" },
	}

	rows.network = {
		{ label = "Internal", value = data and data.Internal, value_hl = "DockyardMuted" },
		{ label = "Attachable", value = data and data.Attachable, value_hl = "DockyardMuted" },
		{ label = "Ingress", value = data and data.Ingress, value_hl = "DockyardMuted" },
		{ label = "Enable IPv6", value = data and data.EnableIPv6, value_hl = "DockyardMuted" },
		{ label = "Labels", value = tostring(type(data and data.Labels) == "table" and vim.tbl_count(data.Labels) or 0), value_hl = "DockyardMuted" },
		{ label = "Options", value = tostring(type(data and data.Options) == "table" and vim.tbl_count(data.Options) or 0), value_hl = "DockyardMuted" },
	}

	local cfg = ipam.Config
	local subnet = "-"
	local gateway = "-"
	if type(cfg) == "table" and #cfg > 0 then
		subnet = v(cfg[1].Subnet)
		gateway = v(cfg[1].Gateway)
	end

	rows.ipam = {
		{ label = "IPAM Driver", value = ipam.Driver, value_hl = "DockyardMuted" },
		{ label = "Subnet", value = subnet, value_hl = "DockyardPorts" },
		{ label = "Gateway", value = gateway, value_hl = "DockyardPorts" },
	}

	local names = {}
	for _, cid in ipairs(keys(containers)) do
		local c = containers[cid] or {}
		table.insert(names, string.format("%s (%s)", v(c.Name), v(c.IPv4Address)))
	end

	rows.attachments = {
		{ label = "Attached", value = tostring(#names), value_hl = "DockyardPorts" },
		{ label = "Containers", value = #names > 0 and table.concat(names, ", ") or "-", value_hl = "DockyardMuted" },
	}

	return rows
end

local function render_popup_content()
	if popup == nil or last_item == nil then
		return
	end

	local width = popup.get_width()
	local rows = build_rows(last_item, last_data)
	local lines, spans = {}, {}

	append_table_rows(lines, spans, rows.header, width)
	render_section(lines, spans, "NETWORK")
	append_table_rows(lines, spans, rows.network, width)
	render_section(lines, spans, "IPAM")
	append_table_rows(lines, spans, rows.ipam, width)
	render_section(lines, spans, "ATTACHMENTS")
	append_table_rows(lines, spans, rows.attachments, width)

	popup.set_content(lines, spans)
end

local function reset_cached_data()
	last_item = nil
	last_data = nil
end

local function refresh_popup_data()
	if last_item == nil or not last_item.id then
		return
	end

	docker.inspect("network", last_item.id, function(res)
		if not res.ok then
			last_data = nil
			render_popup_content()
			return
		end

		last_data = res.data or {}
		render_popup_content()
	end)
end

popup = generic_popup.create({
	title = " Network ",
	view = "network",
	on_resize = function()
		render_popup_content()
	end,
	on_close = reset_cached_data,
})

---@param item Network|nil
function M.open(item)
	if not item or not item.id then
		vim.notify("Dockyard: select a network row", vim.log.levels.WARN)
		return
	end

	last_item = item
	last_data = nil

	local title = string.format(" Network: %s ", v(last_item.name))
	local _, buf = popup.open({
		title = title,
		footer = " Refresh (r) ",
		view = "network",
	})

	local opts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "r", refresh_popup_data, opts)

	render_popup_content()
	refresh_popup_data()
end

return M
