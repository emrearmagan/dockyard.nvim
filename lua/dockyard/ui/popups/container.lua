local docker = require("dockyard.docker")
local highlights = require("dockyard.ui.highlights")

local M = {}

local popup_win = nil
local popup_buf = nil
local ns = vim.api.nvim_create_namespace("dockyard.container_inspect")

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

local function render_row(lines, spans, row)
	local label = tostring(row.label) .. ":"
	local width = row.width or 18
	local label_part = string.format("  %-" .. width .. "s ", label)
	local value_part = v(row.value)
	local text = label_part .. value_part
	local lnum = #lines
	table.insert(lines, text)

	table.insert(spans, {
		line = lnum,
		start_col = 2,
		end_col = 2 + #label,
		hl_group = row.label_hl or "DockyardColumnHeader",
	})
	table.insert(spans, {
		line = lnum,
		start_col = #label_part,
		end_col = #text,
		hl_group = row.value_hl or "DockyardName",
	})
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

local function render_rows(lines, spans, rows)
	for _, row in ipairs(rows) do
		render_row(lines, spans, row)
	end
end

local function build_rows(data)
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
		{ label = "Restart Count", value = state.RestartCount, value_hl = "DockyardMuted" },
		{ label = "Health", value = (state.Health or {}).Status, value_hl = "DockyardName" },
		{ label = "Restart Policy", value = (host.RestartPolicy or {}).Name, value_hl = "DockyardMuted" },
	}

	rows.network = {}
	local networks = (data.NetworkSettings or {}).Networks or {}
	local network_names = keys(networks)
	if #network_names == 0 then
		table.insert(rows.network, { label = "Network", value = "No networks found", value_hl = "DockyardMuted" })
	else
		for _, name in ipairs(network_names) do
			local net = networks[name] or {}
			table.insert(rows.network, { label = "Network", value = name, value_hl = "DockyardImage" })
			table.insert(
				rows.network,
				{ label = "  IP Address", value = net.IPAddress, label_hl = "DockyardMuted", value_hl = "DockyardPorts" }
			)
			table.insert(
				rows.network,
				{ label = "  Gateway", value = net.Gateway, label_hl = "DockyardMuted", value_hl = "DockyardMuted" }
			)
		end
	end

	local ports = (data.NetworkSettings or {}).Ports or {}
	local port_keys = keys(ports)
	if #port_keys > 0 then
		table.insert(rows.network, { label = "Ports", value = "" })
		for _, port in ipairs(port_keys) do
			local mapping = ports[port]
			if mapping == vim.NIL or mapping == nil then
				table.insert(
					rows.network,
					{
						label = "  " .. port,
						value = "not published",
						label_hl = "DockyardMuted",
						value_hl = "DockyardMuted",
					}
				)
			elseif type(mapping) == "table" then
				local parts = {}
				for _, m in ipairs(mapping) do
					table.insert(parts, v(m.HostIp) .. ":" .. v(m.HostPort))
				end
				table.insert(
					rows.network,
					{
						label = "  " .. port,
						value = table.concat(parts, ", "),
						label_hl = "DockyardMuted",
						value_hl = "DockyardPorts",
					}
				)
			end
		end
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
		table.insert(rows.config, { label = "Environment", value = "" })
		for _, e in ipairs(env) do
			local k, val = tostring(e):match("([^=]+)=(.*)")
			if k then
				table.insert(
					rows.config,
					{ label = "  " .. k, value = val, label_hl = "DockyardMuted", value_hl = "DockyardName" }
				)
			end
		end
	end

	rows.labels = {}
	local labels = config.Labels or {}
	local label_keys = keys(labels)
	if #label_keys == 0 then
		table.insert(rows.labels, { label = "Labels", value = "-", value_hl = "DockyardMuted" })
	else
		for _, k in ipairs(label_keys) do
			table.insert(
				rows.labels,
				{ label = k, value = labels[k], label_hl = "DockyardMuted", value_hl = "DockyardName" }
			)
		end
	end

	return rows
end

local function render_container(data)
	local lines = {}
	local spans = {}
	local rows = build_rows(data)

	render_rows(lines, spans, rows.header)
	render_section(lines, spans, "NETWORK")
	render_rows(lines, spans, rows.network)
	render_section(lines, spans, "STORAGE")
	render_rows(lines, spans, rows.storage)
	render_section(lines, spans, "CONFIG")
	render_rows(lines, spans, rows.config)
	render_section(lines, spans, "LABELS")
	render_rows(lines, spans, rows.labels)

	return lines, spans
end

local function ensure_popup_buf()
	if popup_buf ~= nil and vim.api.nvim_buf_is_valid(popup_buf) then
		return popup_buf
	end

	popup_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = popup_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = popup_buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = popup_buf })
	vim.api.nvim_set_option_value("filetype", "dockyard_inspect", { buf = popup_buf })
	vim.api.nvim_set_option_value("modifiable", false, { buf = popup_buf })

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = popup_buf,
		once = true,
		callback = function()
			popup_buf = nil
			popup_win = nil
		end,
	})

	return popup_buf
end

local function close_popup()
	if popup_win ~= nil and vim.api.nvim_win_is_valid(popup_win) then
		vim.api.nvim_win_close(popup_win, true)
	end
	popup_win = nil
end

local function open_or_update_popup(buf, item)
	local w = vim.o.columns
	local h = vim.o.lines
	local ww = math.max(math.floor(w * 0.62), 72)
	local wh = math.max(math.floor(h * 0.8), 20)
	local row = math.floor((h - wh) / 2)
	local col = math.floor((w - ww) / 2)

	if popup_win ~= nil and vim.api.nvim_win_is_valid(popup_win) then
		vim.api.nvim_win_set_config(popup_win, {
			relative = "editor",
			width = ww,
			height = wh,
			row = row,
			col = col,
			zindex = 250,
		})
		vim.api.nvim_set_current_win(popup_win)
	else
		popup_win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = ww,
			height = wh,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " Inspect: " .. v(item.name or item.id) .. " ",
			title_pos = "center",
			zindex = 250,
		})
	end

	vim.api.nvim_set_option_value("wrap", false, { win = popup_win })
	vim.api.nvim_set_option_value("cursorline", false, { win = popup_win })
end

function M.open(item)
	if not item or not item.id then
		vim.notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end

	docker.inspect("container", item.id, function(res)
		if not res.ok then
			vim.notify("Inspect failed: " .. tostring(res.error), vim.log.levels.ERROR)
			return
		end

		local buf = ensure_popup_buf()
		local lines, spans = render_container(res.data or {})

		vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

		for _, span in ipairs(spans) do
			vim.api.nvim_buf_add_highlight(buf, ns, span.hl_group, span.line, span.start_col, span.end_col)
		end

		open_or_update_popup(buf, item)

		local opts = { buffer = buf, nowait = true, silent = true }
		vim.keymap.set("n", "q", close_popup, opts)
		vim.keymap.set("n", "<Esc>", close_popup, opts)
	end)
end

return M
