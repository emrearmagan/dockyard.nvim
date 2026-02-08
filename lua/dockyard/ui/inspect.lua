local state = require("dockyard.ui.state")
local colors = require("dockyard.ui.colors")

local M = {}

local inspect_win = nil
local inspect_buf = nil
local namespace = vim.api.nvim_create_namespace("dockyard_inspect")

local function add_field(lines, highlights, label, value, label_hl, value_hl, width)
	local w = width or 15
	local label_text = tostring(label) .. ":"
	local label_str = string.format("  %-" .. w .. "s ", label_text)
	local line = label_str .. (tostring(value or "-"))
	table.insert(lines, line)
	
	table.insert(highlights, {
		line = #lines - 1,
		col_start = 2,
		col_end = 2 + #label_text,
		group = tostring(label_hl or "DockyardColumnHeader"),
	})
	
	table.insert(highlights, {
		line = #lines - 1,
		col_start = #label_str,
		col_end = -1,
		group = tostring(value_hl or "DockyardName"),
	})
end

local function add_section(lines, highlights, title)
	table.insert(lines, "")
	local line = string.format(" %s ", tostring(title))
	table.insert(lines, line)
	table.insert(highlights, {
		line = #lines - 1,
		col_start = 0,
		col_end = -1,
		group = "DockyardHeader",
	})
	table.insert(lines, "")
end

local function render_inspect(data, item)
	local lines = {}
	local highlights = {}

	-- Determine type (very basic check)
	local is_container = data.Config ~= nil and data.State ~= nil
	local is_image = data.RepoTags ~= nil or data.RootFS ~= nil
	local is_network = data.Driver ~= nil and data.IPAM ~= nil

	if is_container then
		-- Details Header removed as requested
		add_field(lines, highlights, "Name", data.Name:gsub("^/", ""), nil, "DockyardName")
		add_field(lines, highlights, "ID", data.Id:sub(1, 12), nil, "DockyardBadgeBlue")
		
		local status = data.State.Status:upper()
		local status_hl = data.State.Running and "DockyardBadgeGreen" or (data.State.Status == "restarting" and "DockyardBadgeYellow" or "DockyardBadgeRed")
		add_field(lines, highlights, "Status", " " .. status .. " ", nil, status_hl)
		
		add_field(lines, highlights, "Image", data.Config.Image, nil, "DockyardBadgeMauve")
		add_field(lines, highlights, "Created", data.Created:sub(1, 19):gsub("T", " "), nil, "DockyardMuted")

		add_section(lines, highlights, "NETWORK")
		local net_settings = data.NetworkSettings or {}
		local max_net_k = 10
		for net_name, _ in pairs(net_settings.Networks or {}) do
			max_net_k = math.max(max_net_k, #net_name)
		end

		for net_name, net in pairs(net_settings.Networks or {}) do
			add_field(lines, highlights, "Network", net_name, nil, "DockyardBadgeMauve")
			add_field(lines, highlights, "  IP Address", net.IPAddress, "DockyardMuted", "DockyardPorts", max_net_k + 4)
			add_field(lines, highlights, "  Gateway", net.Gateway, "DockyardMuted", "DockyardMuted", max_net_k + 4)
		end

		if net_settings.Ports and next(net_settings.Ports) then
			add_field(lines, highlights, "Ports", "")
			for port, mapping in pairs(net_settings.Ports) do
				local map_str = ""
				if mapping then
					for _, m in ipairs(mapping) do
						map_str = map_str .. m.HostIp .. ":" .. m.HostPort .. " -> "
					end
				end
				add_field(lines, highlights, "  " .. port, map_str .. port, "DockyardMuted")
			end
		end

		add_section(lines, highlights, "STORAGE")
		if data.Mounts and #data.Mounts > 0 then
			for _, mount in ipairs(data.Mounts) do
				add_field(lines, highlights, mount.Type:upper(), mount.Source .. " -> " .. mount.Destination, "DockyardMuted", "DockyardImage")
			end
		else
			table.insert(lines, "  No mounts found")
			table.insert(highlights, { line = #lines - 1, col_start = 2, col_end = -1, group = "DockyardMuted" })
		end

		add_section(lines, highlights, "CONFIG")
		add_field(lines, highlights, "Command", table.concat(data.Config.Cmd or {}, " "), nil, "DockyardPorts")
		if data.Config.Env and #data.Config.Env > 0 then
			add_field(lines, highlights, "Environment", "")
			local env_pairs = {}
			local max_k = 0
			for _, env in ipairs(data.Config.Env) do
				local k, v = env:match("([^=]+)=(.*)")
				if k then
					max_k = math.max(max_k, #k)
					table.insert(env_pairs, { k, v })
				end
			end
			
			-- Align to max key length + indent
			for _, p in ipairs(env_pairs) do
				add_field(lines, highlights, "  " .. p[1], p[2], "DockyardMuted", "DockyardName", max_k + 4)
			end
		end

	elseif is_image then
		-- Details Header removed as requested
		add_field(lines, highlights, "ID", data.Id:sub(1, 12), nil, "DockyardBadgeBlue")
		add_field(lines, highlights, "Repo Tags", table.concat(data.RepoTags or {}, ", "), nil, "DockyardBadgeMauve")
		add_field(lines, highlights, "Size", string.format("%.2f MB", data.Size / 1024 / 1024), nil, "DockyardBadgePeach")
		add_field(lines, highlights, "OS/Arch", data.Os .. "/" .. data.Architecture, nil, "DockyardName")
		add_field(lines, highlights, "Author", data.Author ~= "" and data.Author or "-", nil, "DockyardMuted")
		add_field(lines, highlights, "Created", data.Created:sub(1, 19):gsub("T", " "), nil, "DockyardMuted")

		if data.Config and data.Config.ExposedPorts then
			add_section(lines, highlights, "EXPOSED PORTS")
			for port, _ in pairs(data.Config.ExposedPorts) do
				add_field(lines, highlights, "Port", port, nil, "DockyardPorts")
			end
		end

	elseif is_network then
		-- Details Header removed as requested
		add_field(lines, highlights, "Name", data.Name, nil, "DockyardName")
		add_field(lines, highlights, "ID", data.Id:sub(1, 12), nil, "DockyardBadgeBlue")
		add_field(lines, highlights, "Driver", data.Driver, nil, "DockyardBadgeMauve")
		add_field(lines, highlights, "Scope", data.Scope, nil, "DockyardBadgePeach")
		add_field(lines, highlights, "Created", data.Created:sub(1, 19):gsub("T", " "), nil, "DockyardMuted")

		add_section(lines, highlights, "CONTAINERS")
		if data.Containers and next(data.Containers) then
			for _, cnt in pairs(data.Containers) do
				add_field(lines, highlights, cnt.Name, cnt.IPv4Address, nil, "DockyardPorts")
			end
		else
			table.insert(lines, "  No containers connected")
			table.insert(highlights, { line = #lines - 1, col_start = 2, col_end = -1, group = "DockyardMuted" })
		end
	else
		-- Fallback to JSON if unknown type
		local formatted = vim.fn.system("jq .", vim.json.encode(data))
		if vim.v.shell_error ~= 0 then
			lines = vim.split(vim.json.encode(data), "\n")
		else
			lines = vim.split(formatted, "\n")
		end
	end

	return lines, highlights
end

function M.open(item)
	if not item or not (item.id or item.name) then return end

	local id = item.id or item.name
	local data, err = require("dockyard.docker").inspect(id)
	if err then
		vim.notify("Dockyard: " .. err, vim.log.levels.ERROR)
		return
	end

	-- Create buffer if not exists
	if not inspect_buf or not vim.api.nvim_buf_is_valid(inspect_buf) then
		inspect_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_option(inspect_buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(inspect_buf, "filetype", "dockyard_inspect")
	end

	local lines, highlights = render_inspect(data, item)

	vim.api.nvim_buf_set_option(inspect_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(inspect_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(inspect_buf, "modifiable", false)

	-- Calculate size
	local editor_w = vim.o.columns
	local editor_h = vim.o.lines
	local width = math.floor(editor_w * 0.6)
	local height = math.floor(editor_h * 0.8)
	local row = math.floor((editor_h - height) / 2)
	local col = math.floor((editor_w - width) / 2)

	if inspect_win and vim.api.nvim_win_is_valid(inspect_win) then
		vim.api.nvim_win_set_config(inspect_win, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
		})
	else
		inspect_win = vim.api.nvim_open_win(inspect_buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
			title = " Inspect: " .. (item.name or item.repository or item.id) .. " ",
			title_pos = "center",
		})
	end

	-- Apply Highlights
	vim.api.nvim_buf_clear_namespace(inspect_buf, namespace, 0, -1)
	for _, hl in ipairs(highlights) do
		if type(hl.group) == "string" then
			vim.api.nvim_buf_add_highlight(inspect_buf, namespace, hl.group, hl.line, hl.col_start, hl.col_end)
		end
	end

	-- Keybindings to close
	local opts = { buffer = inspect_buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", function()
		if inspect_win and vim.api.nvim_win_is_valid(inspect_win) then
			vim.api.nvim_win_close(inspect_win, true)
		end
		inspect_win = nil
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		if inspect_win and vim.api.nvim_win_is_valid(inspect_win) then
			vim.api.nvim_win_close(inspect_win, true)
		end
		inspect_win = nil
	end, opts)
end

return M
