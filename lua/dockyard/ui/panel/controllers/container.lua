---FIX: Holy please cleanup this mess, but works for now :))
local M = {}

local panel_state = require("dockyard.ui.panel.state")
local chips = require("dockyard.ui.panel.components.chips")
local tabs = require("dockyard.ui.panel.components.tabs")
local icons = require("dockyard.ui.icons")
local highlights = require("dockyard.ui.highlights")
local log_core = require("dockyard.core.stream.loglens.core")
local table_renderer = require("dockyard.ui.components.table")
local highlighter = require("dockyard.ui.loglens.highlight")
local chart = require("dockyard.ui.components.chart")
local stats_stream = require("dockyard.core.stream.stats.stream")
local top_stream = require("dockyard.core.stream.top.stream")
local docker = require("dockyard.core.docker")

local TABS = {
	{ key = "logs", label = "Logs" },
	{ key = "stats", label = "Stats" },
	{ key = "env", label = "Env" },
	{ key = "config", label = "Configuration" },
	{ key = "top", label = "Top" },
}

local state = {
	current_tab = nil,
	stream_instance = nil,
	stats_instance = nil,
	stats_container_id = nil,
	top_instance = nil,
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

local function ensure_inspect(container_id)
	if state.inspect_id == container_id then
		return state.inspect_data
	end

	if state.inspect_loading then
		return nil
	end

	state.inspect_id = container_id
	state.inspect_data = nil
	state.inspect_loading = true

	local requested_id = container_id
	docker.inspect("container", container_id, function(result)
		if state.inspect_id ~= requested_id then
			return
		end
		state.inspect_loading = false
		if result.ok and result.data then
			state.inspect_data = result.data
			if state.current_tab == "env" or state.current_tab == "config" then
				local panel = require("dockyard.ui.panel")
				panel.render()
			end
		end
	end)

	return nil
end

function M.tabs()
	return TABS
end

-- Log stream

local function stop_log_stream()
	if state.stream_instance then
		state.stream_instance:stop()
		state.stream_instance = nil
	end
end

local function ensure_log_stream(container)
	if
		state.stream_instance
		and state.stream_instance.container
		and state.stream_instance.container.id == container.id
	then
		return state.stream_instance
	end

	stop_log_stream()

	state.stream_instance = log_core.create({
		max_lines = 500,
		on_entries = function(_)
			if state.current_tab == "logs" then
				local panel = require("dockyard.ui.panel")
				panel.render()
			end
		end,
	})

	local ok, err = state.stream_instance:start(container)
	if not ok then
		vim.notify("Panel: " .. tostring(err), vim.log.levels.ERROR)
		state.stream_instance = nil
		return nil
	end

	return state.stream_instance
end

-- Top stream

local function stop_top_stream()
	if state.top_instance then
		state.top_instance:stop()
		state.top_instance = nil
	end
end

local function ensure_top_stream(container_id)
	if state.top_instance and state.top_instance.container_id == container_id then
		return state.top_instance
	end

	stop_top_stream()

	state.top_instance = top_stream.create({
		on_update = function()
			if state.current_tab == "top" then
				local panel = require("dockyard.ui.panel")
				panel.render()
			end
		end,
	})

	state.top_instance:start(container_id)
	return state.top_instance
end

-- Stats stream

local function stop_stats_stream()
	if state.stats_instance then
		state.stats_instance:stop()
		state.stats_instance = nil
	end
end

local function ensure_stats_stream(container_id)
	if state.stats_instance and state.stats_container_id == container_id then
		return state.stats_instance
	end

	stop_stats_stream()

	state.stats_instance = stats_stream.create({
		max_history = 100,
		on_update = function()
			if state.current_tab == "stats" then
				local panel = require("dockyard.ui.panel")
				panel.render()
			end
		end,
	})

	state.stats_container_id = container_id
	state.stats_instance:start(container_id)
	return state.stats_instance
end

-- Logs tab rendering

---@param rows table[]
---@param order string[]|nil
---@return table[]
local function infer_columns(rows, order)
	local first = rows[1]
	if type(first) ~= "table" then
		return {}
	end

	local cols = {}
	if type(order) == "table" then
		for _, key in ipairs(order) do
			if type(key) == "string" and first[key] ~= nil then
				table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
			end
		end
	else
		for key, _ in pairs(first) do
			table.insert(cols, { key = key, name = key:gsub("^%l", string.upper) })
		end
	end

	return cols
end

---@param entries LogLensEntry[]
---@return table[] rows
local function entries_to_rows(entries)
	local rows = {}
	for _, entry in ipairs(entries) do
		if type(entry) == "table" and type(entry.data) == "table" then
			table.insert(rows, entry.data)
		end
	end
	return rows
end

---@param width number
---@return string[] lines, table[] spans
local function render_logs(width)
	local node = panel_state.current_node
	if not node or not node.item then
		return { "", "  No container selected" }, {}
	end

	local inst = ensure_log_stream(node.item)
	if not inst then
		return { "", "  Failed to start log stream" }, {}
	end

	if #inst.entries == 0 then
		local lines = { "", "  Waiting for logs..." }
		local spans = {
			{ line = 1, start_col = 2, end_col = #lines[2], hl_group = "DockyardMuted" },
		}
		return lines, spans
	end

	local source = inst.active_source or {}
	local rows = entries_to_rows(inst.entries)
	local columns = infer_columns(rows, source._order)
	if #columns == 0 then
		return { "", "  No log data" }, {}
	end

	local tbl_lines, _, tbl_spans = table_renderer.render({
		columns = columns,
		rows = rows,
		width = width,
		margin = 1,
		fill = false,
	})

	local rules = highlighter.normalize_rules(source.highlights)
	if #rules > 0 then
		for i = 3, #tbl_lines do
			local hl_spans = highlighter.find_spans(tbl_lines[i], rules, i - 1, 0)
			for _, s in ipairs(hl_spans) do
				table.insert(tbl_spans, s)
			end
		end
	end

	return tbl_lines, tbl_spans
end

-- Stats tab rendering

---@param lines string[]
---@param spans table[]
---@param title string
---@param rows table[]
---@param margin number
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

---@param width number
---@return string[] lines, table[] spans
local function render_stats(width)
	local node = panel_state.current_node
	if not node or not node.item then
		return { "", "  No container selected" }, {}
	end

	local inst = ensure_stats_stream(node.item.id)
	if not inst then
		return { "", "  Failed to start stats stream" }, {}
	end

	if not inst.latest then
		local lines = { "", "  Waiting for stats..." }
		local spans = {
			{ line = 1, start_col = 2, end_col = #lines[2], hl_group = "DockyardMuted" },
		}
		return lines, spans
	end

	local lines = {}
	local spans = {}
	local latest = inst.latest

	-- CPU chart
	local cpu_lines, cpu_spans = chart.render({
		data = inst:cpu_data(),
		width = width,
		height = 6,
		title = "CPU",
		value = latest.cpu_perc or "-",
		hl_group = "DockyardChartCPU",
		title_hl = "DockyardChartCPU",
		value_hl = "DockyardChartCPU",
		margin = 1,
	})

	local cpu_start = #lines
	for _, l in ipairs(cpu_lines) do
		table.insert(lines, l)
	end
	for _, s in ipairs(cpu_spans) do
		s.line = s.line + cpu_start
		table.insert(spans, s)
	end

	table.insert(lines, "")

	-- Memory chart
	local mem_lines, mem_spans = chart.render({
		data = inst:mem_data(),
		width = width,
		height = 6,
		title = "Memory",
		value = latest.mem_perc or "-",
		hl_group = "DockyardChartMemory",
		title_hl = "DockyardChartMemory",
		value_hl = "DockyardChartMemory",
		margin = 1,
	})

	local mem_start = #lines
	for _, l in ipairs(mem_lines) do
		table.insert(lines, l)
	end
	for _, s in ipairs(mem_spans) do
		s.line = s.line + mem_start
		table.insert(spans, s)
	end

	table.insert(lines, "")

	-- Detail sections
	append_detail_section(lines, spans, "CPU Stats", {
		{ "Current", latest.cpu_perc or "-", "DockyardPorts" },
		{ "Average", string.format("%.2f%%", inst:cpu_avg()), "DockyardPorts" },
		{ "Peak", string.format("%.2f%%", inst:cpu_peak()), "DockyardPorts" },
	}, 1)

	table.insert(lines, "")

	append_detail_section(lines, spans, "Memory Stats", {
		{ "Usage", latest.mem_usage or "-", "DockyardPorts" },
		{ "Percentage", latest.mem_perc or "-", "DockyardPorts" },
		{ "Peak", string.format("%.2f%%", inst:mem_peak()), "DockyardPorts" },
	}, 1)

	table.insert(lines, "")

	append_detail_section(lines, spans, "I/O Stats", {
		{ "Network", latest.net_io or "-", "DockyardName" },
		{ "Block", latest.block_io or "-", "DockyardName" },
	}, 1)

	table.insert(lines, "")

	append_detail_section(lines, spans, "Processes", {
		{ "PIDs", latest.pids or "-", "DockyardImage" },
	}, 1)

	return lines, spans
end

-- Top tab rendering

---@param width number
---@return string[] lines, table[] spans
local function render_top(width)
	local node = panel_state.current_node
	if not node or not node.item then
		return { "", "  No container selected" }, {}
	end

	local inst = ensure_top_stream(node.item.id)
	if not inst then
		return { "", "  Failed to start top stream" }, {}
	end

	if #inst.rows == 0 then
		local lines = { "", "  Waiting for processes..." }
		local spans = {
			{ line = 1, start_col = 2, end_col = #lines[2], hl_group = "DockyardMuted" },
		}
		return lines, spans
	end

	local tbl_lines, _, tbl_spans = table_renderer.render({
		columns = inst.columns,
		rows = inst.rows,
		width = width,
		margin = 1,
		fill = false,
	})

	return tbl_lines, tbl_spans
end

-- Env tab rendering

---@param width number
---@return string[] lines, table[] spans
local function render_env(width)
	local node = panel_state.current_node
	if not node or not node.item then
		return { "", "  No container selected" }, {}
	end

	local data = ensure_inspect(node.item.id)
	if not data then
		local lines = { "", "  Loading..." }
		return lines, { { line = 1, start_col = 2, end_col = #lines[2], hl_group = "DockyardMuted" } }
	end

	local env_array = (data.Config and data.Config.Env) or {}
	if #env_array == 0 then
		local lines = { "", "  No environment variables" }
		return lines, { { line = 1, start_col = 2, end_col = #lines[2], hl_group = "DockyardMuted" } }
	end

	local rows = {}
	for _, entry in ipairs(env_array) do
		local key, value = entry:match("^([^=]+)=(.*)")
		if key then
			table.insert(rows, { key = key, value = value })
		end
	end

	local tbl_lines, _, tbl_spans = table_renderer.render({
		columns = {
			{ key = "key", name = "Key", max_width = 40 },
			{ key = "value", name = "Value" },
		},
		rows = rows,
		width = width,
		margin = 1,
		fill = false,
	})

	return tbl_lines, tbl_spans
end

-- Config tab rendering

---@param width number
---@return string[] lines, table[] spans
local function render_config(width)
	local node = panel_state.current_node
	if not node or not node.item then
		return { "", "  No container selected" }, {}
	end

	local data = ensure_inspect(node.item.id)
	if not data then
		local lines = { "", "  Loading..." }
		return lines, { { line = 1, start_col = 2, end_col = #lines[2], hl_group = "DockyardMuted" } }
	end

	local lines = {}
	local spans = {}
	local cfg = data.Config or {}
	local hc = data.HostConfig or {}
	local state = data.State or {}
	local net_settings = data.NetworkSettings or {}

	-- General
	local cmd = type(cfg.Cmd) == "table" and table.concat(cfg.Cmd, " ") or tostring(cfg.Cmd or "-")
	local entrypoint = type(cfg.Entrypoint) == "table" and table.concat(cfg.Entrypoint, " ")
		or tostring(cfg.Entrypoint or "")
	append_detail_section(lines, spans, "General", {
		{ "Image", cfg.Image or "-" },
		{ "Cmd", cmd ~= "" and cmd or "-" },
		{ "Entrypoint", entrypoint ~= "" and entrypoint or "-" },
		{ "Working Dir", (cfg.WorkingDir ~= "") and cfg.WorkingDir or "-" },
		{ "User", (cfg.User and cfg.User ~= "") and cfg.User or "root" },
	}, 1)

	-- State
	table.insert(lines, "")
	local started = type(state.StartedAt) == "string" and state.StartedAt:sub(1, 19):gsub("T", " ") or "-"
	local health = state.Health and state.Health.Status or "-"
	local state_rows = {
		{ "Started", started },
		{ "Exit Code", tostring(state.ExitCode or 0) },
		{ "Health", health },
	}
	if state.RestartCount and state.RestartCount > 0 then
		table.insert(state_rows, { "Restarts", tostring(state.RestartCount) })
	end
	append_detail_section(lines, spans, "State", state_rows, 1)

	-- Runtime
	table.insert(lines, "")
	local memory = (hc.Memory and hc.Memory > 0) and string.format("%.0f MB", hc.Memory / 1024 / 1024) or "unlimited"
	local cpu = (hc.CpuShares and hc.CpuShares > 0) and tostring(hc.CpuShares) or "default"
	local restart = (hc.RestartPolicy and hc.RestartPolicy.Name ~= "") and hc.RestartPolicy.Name or "no"
	append_detail_section(lines, spans, "Runtime", {
		{ "Restart Policy", restart },
		{ "Memory", memory },
		{ "CPU Shares", cpu },
	}, 1)

	-- Network
	table.insert(lines, "")
	local net_rows = { { "Mode", hc.NetworkMode or "-" } }
	local networks = type(net_settings.Networks) == "table" and net_settings.Networks or {}
	for name, net in pairs(networks) do
		local ip = (net.IPAddress and net.IPAddress ~= "") and net.IPAddress or "-"
		table.insert(net_rows, { name, ip })
	end
	local ports = type(net_settings.Ports) == "table" and net_settings.Ports or {}
	for port, mapping in pairs(ports) do
		if type(mapping) == "table" and #mapping > 0 then
			local parts = {}
			for _, m in ipairs(mapping) do
				table.insert(parts, (m.HostIp or "0.0.0.0") .. ":" .. (m.HostPort or ""))
			end
			table.insert(net_rows, { port, table.concat(parts, ", ") })
		end
	end
	append_detail_section(lines, spans, "Network", net_rows, 1)

	-- Mounts
	local mounts = data.Mounts or {}
	if #mounts > 0 then
		table.insert(lines, "")
		local mount_rows = {}
		for _, mount in ipairs(mounts) do
			local src = mount.Source or ""
			local dst = mount.Destination or ""
			table.insert(mount_rows, { dst, src })
		end
		append_detail_section(lines, spans, "Mounts", mount_rows, 1)
	end

	-- Labels
	local labels = type(cfg.Labels) == "table" and cfg.Labels or {}
	if next(labels) then
		table.insert(lines, "")
		local label_rows = {}
		for k, v in pairs(labels) do
			table.insert(label_rows, { k, v })
		end
		table.sort(label_rows, function(a, b)
			return a[1] < b[1]
		end)
		append_detail_section(lines, spans, "Labels", label_rows, 1)
	end

	return lines, spans
end

-- Main render

---@param width number
---@return string[] lines, table[] spans
function M.render(width)
	local node = panel_state.current_node
	if not node or node.kind ~= "container" then
		return {}, {}
	end

	local active_tab = M.get_tab()

	-- Stop streams that aren't needed for the current tab
	if active_tab ~= "logs" and state.stream_instance then
		stop_log_stream()
	end
	if active_tab ~= "stats" and state.stats_instance then
		stop_stats_stream()
	end
	if active_tab ~= "top" and state.top_instance then
		stop_top_stream()
	end

	local lines = {}
	local spans = {}

	-- Chips
	local item = node and node.item
	if item then
		local chip_items = {
			{
				text = string.format("%s %s", icons.container_icon(item.status), (item.status or "unknown"):upper()),
				hl_group = highlights.status_hl(item.status),
			},
			{
				text = string.format("%s %s", icons.image_icon("image"), item.image or "-"),
				hl_group = "DockyardImage",
			},
		}
		if item.ports and item.ports ~= "" then
			table.insert(chip_items, {
				text = string.format("%s %s", icons.view_icon("network"), item.ports),
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

	-- Tab content
	local content_lines, content_spans = {}, {}
	if active_tab == "logs" then
		content_lines, content_spans = render_logs(width)
	elseif active_tab == "stats" then
		content_lines, content_spans = render_stats(width)
	elseif active_tab == "top" then
		content_lines, content_spans = render_top(width)
	elseif active_tab == "env" then
		content_lines, content_spans = render_env(width)
	elseif active_tab == "config" then
		content_lines, content_spans = render_config(width)
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

function M.on_close()
	stop_log_stream()
	stop_stats_stream()
	stop_top_stream()
	state.inspect_id = nil
	state.inspect_data = nil
	state.inspect_loading = false
end

return M
