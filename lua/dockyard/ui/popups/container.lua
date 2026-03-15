local docker = require("dockyard.docker")
local highlights = require("dockyard.ui.highlights")
local table_view = require("dockyard.ui.components.table")
local generic_popup = require("dockyard.ui.popups.popup")

local M = {}

local last_data = nil
local last_stats = nil
local last_item = nil
local popup = nil

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

local function join_list(items)
	if type(items) ~= "table" or #items == 0 then
		return "-"
	end
	local out = {}
	for _, x in ipairs(items) do
		table.insert(out, v(x))
	end
	return table.concat(out, ", ")
end

local function is_empty_value(x)
	if x == nil then
		return true
	end
	local s = tostring(x)
	return s == "" or s == "-"
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

local function append_table_rows(lines, spans, rows, width)
	local function to_table_row(row)
		local out = {
			field = tostring(row.label or "") .. ":",
			value = v(row.value),
			_label_hl = row.label_hl or "DockyardColumnHeader",
			_value_hl = row.value_hl or "DockyardName",
			_expanded = row._expanded,
		}

		if type(row.children) == "table" and #row.children > 0 then
			out.children = {}
			for _, child in ipairs(row.children) do
				table.insert(out.children, to_table_row(child))
			end
		end

		return out
	end

	local table_rows = {}
	for _, row in ipairs(rows or {}) do
		table.insert(table_rows, to_table_row(row))
	end

	local block_lines, _, block_spans = table_view.render({
		columns = {
			{ key = "field", name = "", width = 24, gap_after = 2 },
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
		tree = {
			expanded_field = "_expanded",
			default_expanded = true,
			show_indicator = false,
		},
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

local function build_rows(data, stats)
	local rows = {}
	local state = data.State or {}
	local config = data.Config or {}
	local host = data.HostConfig or {}
	local status = v(state.Status)

	rows.header = {
		{ label = "Name", value = v(data.Name):gsub("^/", ""), value_hl = "DockyardName" },
		{ label = "ID", value = v(data.Id):sub(1, 12), value_hl = "DockyardRunning" },
		{ label = "Status", value = status:upper() .. " ", value_hl = highlights.status_hl(docker.to_status(status)) },
		{ label = "Image", value = config.Image, value_hl = "DockyardImage" },
		{ label = "Created", value = ts(data.Created), value_hl = "DockyardMuted" },
		{ label = "Started", value = ts(state.StartedAt), value_hl = "DockyardMuted" },
		{ label = "Exit Code", value = state.ExitCode, value_hl = "DockyardPorts" },
		{ label = "Health", value = (state.Health or {}).Status, value_hl = "DockyardName" },
		{ label = "Restart Policy", value = (host.RestartPolicy or {}).Name, value_hl = "DockyardMuted" },
	}

	if not is_empty_value(state.RestartCount) then
		table.insert(
			rows.header,
			8,
			{ label = "Restart Count", value = state.RestartCount, value_hl = "DockyardMuted" }
		)
	end

	if type(stats) == "table" then
		table.insert(rows.header, { label = "CPU", value = stats.cpu_perc, value_hl = "DockyardPorts" })
		table.insert(rows.header, { label = "Memory", value = stats.mem_usage, value_hl = "DockyardPorts" })
		table.insert(rows.header, { label = "Memory %", value = stats.mem_perc, value_hl = "DockyardPorts" })
		table.insert(rows.header, { label = "PIDs", value = stats.pids, value_hl = "DockyardMuted" })
		table.insert(rows.header, { label = "Net IO", value = stats.net_io, value_hl = "DockyardMuted" })
		table.insert(rows.header, { label = "Block IO", value = stats.block_io, value_hl = "DockyardMuted" })
	end

	rows.network = {}
	local networks = (data.NetworkSettings or {}).Networks or {}
	local network_names = keys(networks)
	if #network_names == 0 then
		table.insert(rows.network, { label = "Network", value = "No networks found", value_hl = "DockyardMuted" })
	else
		for _, name in ipairs(network_names) do
			local net = networks[name] or {}
			table.insert(rows.network, {
				label = "Network",
				value = name,
				value_hl = "DockyardImage",
				_expanded = true,
				children = {
					{
						label = "IP Address",
						value = net.IPAddress,
						label_hl = "DockyardMuted",
						value_hl = "DockyardPorts",
					},
					{ label = "Gateway", value = net.Gateway, label_hl = "DockyardMuted", value_hl = "DockyardMuted" },
				},
			})
		end
	end

	local ports = (data.NetworkSettings or {}).Ports or {}
	local port_keys = keys(ports)
	if #port_keys > 0 then
		local port_children = {}
		for _, port in ipairs(port_keys) do
			local mapping = ports[port]
			if mapping == vim.NIL or mapping == nil then
				table.insert(port_children, {
					label = port,
					value = "not published",
					label_hl = "DockyardMuted",
					value_hl = "DockyardMuted",
				})
			elseif type(mapping) == "table" then
				local parts = {}
				for _, m in ipairs(mapping) do
					table.insert(parts, v(m.HostIp) .. ":" .. v(m.HostPort))
				end
				table.insert(port_children, {
					label = port,
					value = table.concat(parts, ", "),
					label_hl = "DockyardMuted",
					value_hl = "DockyardPorts",
				})
			end
		end

		table.insert(rows.network, {
			label = "Ports",
			value = "",
			_expanded = true,
			children = port_children,
		})
	end

	rows.storage = {}
	local mounts = data.Mounts or {}
	if #mounts == 0 then
		table.insert(rows.storage, { label = "Mounts", value = "No mounts found", value_hl = "DockyardMuted" })
	else
		for _, mount in ipairs(mounts) do
			table.insert(rows.storage, {
				label = v(mount.Type):upper(),
				value = v(mount.Source) .. " -> " .. v(mount.Destination),
				label_hl = "DockyardMuted",
				value_hl = "DockyardImage",
			})
		end
	end

	rows.config = {
		{ label = "Path", value = data.Path, value_hl = "DockyardPorts" },
		{ label = "Args", value = join_list(data.Args), value_hl = "DockyardPorts" },
		{ label = "Entrypoint", value = join_list(config.Entrypoint), value_hl = "DockyardPorts" },
		{ label = "Command", value = join_list(config.Cmd), value_hl = "DockyardPorts" },
		{ label = "Working Dir", value = config.WorkingDir, value_hl = "DockyardMuted" },
	}

	local env = config.Env or {}
	if #env > 0 then
		local env_children = {}
		for _, e in ipairs(env) do
			local k, val = tostring(e):match("([^=]+)=(.*)")
			if k then
				table.insert(
					env_children,
					{ label = k, value = val, label_hl = "DockyardMuted", value_hl = "DockyardName" }
				)
			end
		end
		table.insert(rows.config, {
			label = "Environment",
			value = "",
			_expanded = true,
			children = env_children,
		})
	end

	rows.labels = {}
	local labels = config.Labels or {}
	local label_keys = keys(labels)
	if #label_keys == 0 then
		table.insert(rows.labels, { label = "Labels", value = "-", value_hl = "DockyardMuted" })
	else
		local label_children = {}
		for _, k in ipairs(label_keys) do
			table.insert(
				label_children,
				{ label = k, value = labels[k], label_hl = "DockyardMuted", value_hl = "DockyardName" }
			)
		end
		table.insert(rows.labels, {
			label = "Labels",
			value = string.format("%d items", #label_children),
			value_hl = "DockyardMuted",
			_expanded = true,
			children = label_children,
		})
	end

	return rows
end

local function render_container(data, stats, width)
	local lines = {}
	local spans = {}
	local rows = build_rows(data, stats)

	append_table_rows(lines, spans, rows.header, width)
	render_section(lines, spans, "NETWORK")
	append_table_rows(lines, spans, rows.network, width)
	render_section(lines, spans, "STORAGE")
	append_table_rows(lines, spans, rows.storage, width)
	render_section(lines, spans, "CONFIG")
	append_table_rows(lines, spans, rows.config, width)
	render_section(lines, spans, "LABELS")
	append_table_rows(lines, spans, rows.labels, width)

	return lines, spans
end

local function reset_cached_data()
	last_data = nil
	last_stats = nil
	last_item = nil
end

local function render_popup_content()
	if last_data == nil or popup == nil then
		return
	end
	local width = popup.get_width()
	local lines, spans = render_container(last_data, last_stats, width)
	popup.set_content(lines, spans)
end

local function refresh_popup_data()
	if last_item == nil or last_item.id == nil then
		return
	end

	docker.inspect("container", last_item.id, function(res)
		if not res.ok then
			vim.notify("Inspect failed: " .. tostring(res.error), vim.log.levels.ERROR)
			return
		end

		last_data = res.data or {}
		last_stats = nil
		render_popup_content()

		docker.container_stats(last_item.id, function(stats_res)
			if not stats_res.ok or popup == nil or not popup.is_open() then
				return
			end
			if last_data == nil or last_item == nil then
				return
			end

			last_stats = stats_res.data or {}
			render_popup_content()
		end)
	end)
end

popup = generic_popup.create({
	title = " Inspect ",
	view = "container",
	on_resize = function()
		render_popup_content()
	end,
	on_close = reset_cached_data,
})

function M.open(item)
	if not item or not item.id then
		vim.notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end

	last_item = item
	local _, buf = popup.open({
		title = " Inspect: " .. v(item.name or item.id) .. " ",
		footer = " Refresh (r) ",
		view = "container",
	})

	local opts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "r", function()
		refresh_popup_data()
	end, opts)

	refresh_popup_data()
end

return M
