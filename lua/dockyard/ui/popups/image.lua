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
	if #s >= 19 then
		return s:sub(1, 19)
	end
	return s
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
	local cfg = (data and data.Config) or {}
	local rootfs = (data and data.RootFS) or {}

	rows.header = {
		{ label = "Repository", value = item.repository, value_hl = "DockyardImage" },
		{ label = "Tag", value = item.tag, value_hl = "DockyardImage" },
		{ label = "Image ID", value = v(item.id):sub(1, 12), value_hl = "DockyardRunning" },
		{ label = "Size", value = item.size, value_hl = "DockyardPorts" },
		{ label = "Created", value = item.created_since or ts(item.created), value_hl = "DockyardMuted" },
	}

	rows.image = {
		{ label = "Repo Tags", value = join_list(data and data.RepoTags), value_hl = "DockyardImage" },
		{ label = "Repo Digests", value = join_list(data and data.RepoDigests), value_hl = "DockyardMuted" },
		{ label = "Architecture", value = data and data.Architecture, value_hl = "DockyardMuted" },
		{ label = "OS", value = data and data.Os, value_hl = "DockyardMuted" },
		{ label = "Docker Version", value = data and data.DockerVersion, value_hl = "DockyardMuted" },
		{ label = "Author", value = data and data.Author, value_hl = "DockyardMuted" },
		{ label = "Layers", value = tostring(type(rootfs.Layers) == "table" and #rootfs.Layers or 0), value_hl = "DockyardPorts" },
	}

	rows.config = {
		{ label = "Entrypoint", value = join_list(cfg.Entrypoint), value_hl = "DockyardName" },
		{ label = "Command", value = join_list(cfg.Cmd), value_hl = "DockyardName" },
		{ label = "Working Dir", value = cfg.WorkingDir, value_hl = "DockyardMuted" },
		{ label = "User", value = cfg.User, value_hl = "DockyardMuted" },
		{ label = "Env Count", value = tostring(type(cfg.Env) == "table" and #cfg.Env or 0), value_hl = "DockyardMuted" },
		{ label = "Labels", value = tostring(type(cfg.Labels) == "table" and vim.tbl_count(cfg.Labels) or 0), value_hl = "DockyardMuted" },
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
	render_section(lines, spans, "IMAGE")
	append_table_rows(lines, spans, rows.image, width)
	render_section(lines, spans, "CONFIG")
	append_table_rows(lines, spans, rows.config, width)

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

	docker.inspect("image", last_item.id, function(res)
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
	title = " Image ",
	view = "image",
	on_resize = function()
		render_popup_content()
	end,
	on_close = reset_cached_data,
})

---@param item Image|nil
function M.open(item)
	if not item or not item.id then
		vim.notify("Dockyard: select an image row", vim.log.levels.WARN)
		return
	end

	last_item = item
	last_data = nil

	local title = string.format(" Image: %s:%s ", v(last_item.repository), v(last_item.tag))
	local _, buf = popup.open({
		title = title,
		footer = " Refresh (r) ",
		view = "image",
	})

	local opts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "r", refresh_popup_data, opts)

	render_popup_content()
	refresh_popup_data()
end

return M
