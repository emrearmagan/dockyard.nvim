local M = {}

local panel_state = require("dockyard.ui.panel.state")
local chips = require("dockyard.ui.panel.components.chips")
local tabs = require("dockyard.ui.panel.components.tabs")
local table_renderer = require("dockyard.ui.components.table")
local docker = require("dockyard.docker")

local TABS = {
	{ key = "config", label = "Configuration" },
	{ key = "env", label = "Env" },
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

local function ensure_inspect(image_id)
	if state.inspect_id == image_id then
		return state.inspect_data
	end

	if state.inspect_loading then
		return nil
	end

	state.inspect_id = image_id
	state.inspect_data = nil
	state.inspect_loading = true

	local requested_id = image_id
	docker.inspect("image", image_id, function(result)
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
	local cfg = data.Config or {}

	local cmd = type(cfg.Cmd) == "table" and table.concat(cfg.Cmd, " ") or tostring(cfg.Cmd or "-")
	local entrypoint = type(cfg.Entrypoint) == "table" and table.concat(cfg.Entrypoint, " ")
		or tostring(cfg.Entrypoint or "")
	local created = type(data.Created) == "string" and data.Created:sub(1, 19):gsub("T", " ") or "-"

	local function join_list(t)
		if type(t) ~= "table" or #t == 0 then
			return "-"
		end
		return table.concat(t, ", ")
	end

	append_detail_section(lines, spans, "General", {
		{ "Architecture", data.Architecture or "-" },
		{ "OS", data.Os or "-" },
		{ "Created", created },
		{ "Author", (data.Author and data.Author ~= "") and data.Author or "-" },
		{ "Docker Version", data.DockerVersion or "-" },
		{ "Repo Tags", join_list(data.RepoTags) },
		{ "Repo Digests", join_list(data.RepoDigests) },
	}, 1)

	table.insert(lines, "")

	append_detail_section(lines, spans, "Config", {
		{ "Cmd", cmd ~= "" and cmd or "-" },
		{ "Entrypoint", entrypoint ~= "" and entrypoint or "-" },
		{ "Working Dir", (cfg.WorkingDir and cfg.WorkingDir ~= "") and cfg.WorkingDir or "-" },
		{ "User", (cfg.User and cfg.User ~= "") and cfg.User or "root" },
	}, 1)

	table.insert(lines, "")

	local exposed = {}
	for port, _ in pairs(cfg.ExposedPorts or {}) do
		table.insert(exposed, port)
	end
	table.sort(exposed)

	local layers = data.RootFS and data.RootFS.Layers and #data.RootFS.Layers or 0

	append_detail_section(lines, spans, "Details", {
		{ "Exposed Ports", #exposed > 0 and table.concat(exposed, ", ") or "-" },
		{ "Layers", tostring(layers) },
		{ "Env Vars", tostring(#(cfg.Env or {})) },
	}, 1)

	return lines, spans
end

local function render_env(data, width)
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

function M.tabs()
	return TABS
end

---@param width number
---@return string[] lines, table[] spans
function M.render(width)
	local node = panel_state.current_node
	if not node or node.kind ~= "image" then
		return {}, {}
	end

	local active_tab = M.get_tab()

	local lines = {}
	local spans = {}

	-- Chips
	local item = node and node.item
	if item then
		local chip_items = {
			{ text = string.format("ID: %s", (item.id or "-"):sub(1, 12)), hl_group = "DockyardRunning" },
			{ text = item.size or "-", hl_group = "DockyardPorts" },
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
		elseif active_tab == "env" then
			content_lines, content_spans = render_env(data, width)
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
