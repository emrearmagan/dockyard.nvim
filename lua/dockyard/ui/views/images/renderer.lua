local M = {}

local data_state = require("dockyard.state")
local ui_state = require("dockyard.ui.state")
local config = require("dockyard.config")
local table_view = require("dockyard.ui.components.table")
local header = require("dockyard.ui.components.header")
local navbar = require("dockyard.ui.components.navbar")
local ui_utils = require("dockyard.ui.utils")
local docker = require("dockyard.docker")
local highlights = require("dockyard.ui.highlights")
local view_state = require("dockyard.ui.views.images.state")

local function current_width()
	if ui_state.win_id ~= nil and vim.api.nvim_win_is_valid(ui_state.win_id) then
		return vim.api.nvim_win_get_width(ui_state.win_id)
	end
	return vim.o.columns
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

local function normalize_image_ref(ref)
	local s = tostring(ref or "")
	if s == "" then
		return "<unknown>"
	end

	local digest_pos = s:find("@", 1, true)
	if digest_pos then
		s = s:sub(1, digest_pos - 1)
	end

	return s
end

local function containers_for_image(img, containers)
	local out = {}
	local image_ref = normalize_image_ref((img.repository or "<none>") .. ":" .. (img.tag or "<none>"))
	local image_id = tostring(img.id or "")

	for _, c in ipairs(containers or {}) do
		local c_ref = normalize_image_ref(c.image or c.image_id)
		local c_image = tostring(c.image or "")
		if c_ref == image_ref or c_image == image_id or image_id:find(c_image, 1, true) == 1 then
			table.insert(out, c)
		end
	end

	return out
end

local function image_key(img)
	if img and img.id and img.id ~= "" then
		return "img:" .. tostring(img.id)
	end
	return "img:"
		.. normalize_image_ref((img and img.repository) or "<none>")
		.. ":"
		.. tostring((img and img.tag) or "<none>")
end

local function build_image_parent_row(img, containers)
	local children_src = containers_for_image(img, containers)
	local key = image_key(img)

	table.sort(children_src, function(a, b)
		return tostring(a.name or "") < tostring(b.name or "")
	end)

	local row = {
		kind = "image",
		key = key,
		name = "󰏗 " .. (img.repository or "<none>"),
		tag = img.tag or "<none>",
		image_id = tostring(img.id or ""):sub(1, 12),
		size = img.size_human or img.size or "-",
		created = img.created_since or img.created_at or "-",
		expanded = view_state.expanded[key],
		children = {},
		_item = {
			kind = "image",
			item = img,
			key = key,
		},
	}

	for _, c in ipairs(children_src) do
		local st = docker.to_status(c.status)
		table.insert(row.children, {
			kind = "container",
			name = status_icon(st) .. " " .. (c.name or c.id or "-"),
			tag = "",
			image_id = "",
			size = "",
			created = "",
			_item = {
				kind = "container",
				item = c,
				parent_image = img,
			},
		})
	end

	return row
end

local function to_tree_rows(images, containers)
	local rows = {}
	local sorted = vim.deepcopy(images or {})

	table.sort(sorted, function(a, b)
		local a_ref = tostring(a.repository or "-")
		local b_ref = tostring(b.repository or "-")
		if a_ref == b_ref then
			return tostring(a.tag or "") < tostring(b.tag or "")
		end

		return a_ref < b_ref
	end)

	for _, img in ipairs(sorted) do
		table.insert(rows, build_image_parent_row(img, containers))
	end

	return rows
end

local function cell_hl(row, col)
	if row.kind == "image" then
		if col.key == "name" then
			return "DockyardName"
		end
		if col.key == "tag" then
			return "DockyardImage"
		end
		if col.key == "image_id" then
			return "DockyardRunning"
		end
		return "DockyardMuted"
	end

	if col.key == "name" then
		return "DockyardMuted"
	end
	if col.key == "tag" then
		return "DockyardPorts"
	end
	if col.key == "image_id" then
		return "DockyardMuted"
	end
	return "DockyardMuted"
end

---@param width number
---@return string[] lines, table line_map, table spans
local function build_body(width)
	local image = data_state.images.get_items()
	local container = data_state.containers.get_items()

	local rows = to_tree_rows(image, container)

	local lines, line_map, spans = table_view.render({
		width = width,
		margin = 1,
		columns = {
			{ key = "name", name = "Image / Container", min_width = 28 },
			{ key = "tag", name = "Tag", min_width = 16 },
			{ key = "image_id", name = "ID", min_width = 14 },
			{ key = "size", name = "Size", min_width = 14 },
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
		if node and node.kind == "image" then
			local line = lines[lnum] or ""
			local s = line:find("󰏗", 1, true)
			if s then
				table.insert(spans, {
					line = lnum - 1,
					start_col = s - 1,
					end_col = s - 1 + #"󰏗",
					hl_group = "DockyardImage",
				})
			end
		elseif node and node.kind == "container" and node.item then
			local line = lines[lnum] or ""
			local st = docker.to_status(node.item.status)
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
	ui_utils.append_block(lines, spans, navbar.render({
		width = width,
		current_view = ui_state.current_view,
		views = views,
	}))
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
