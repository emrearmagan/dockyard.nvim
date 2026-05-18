local core = require("dockyard.files.core")
local icons = require("dockyard.ui.icons")
local table_view = require("dockyard.ui.components.table")
local ui_utils = require("dockyard.ui.utils")

local M = {}

---@class DockyardBrowserState
---@field buf integer|nil
---@field container string
---@field path string
---@field entries DockyardFileEntry[]|nil
---@field show_hidden boolean
---@field origin_buf integer|nil
---@field line_map table<integer, table>|nil

---@type DockyardBrowserState
local state = {
	buf = nil,
	container = "",
	path = "/",
	entries = nil,
	show_hidden = false,
	origin_buf = nil,
	line_map = nil,
}

local function notify(msg, level)
	vim.notify("[dockyard] " .. msg, level or vim.log.levels.INFO)
end

local function format_size(n)
	n = tonumber(n) or 0
	local units = { "B", "K", "M", "G", "T" }
	local i = 1
	while n >= 1024 and i < #units do
		n = n / 1024
		i = i + 1
	end
	return ("%6.1f%s"):format(n, units[i])
end

local function row_hl(row, col)
	if col.key == "name" then
		if row.type == "directory" then
			return "DockyardName"
		end
		if row.type == "link" then
			return "DockyardImage"
		end
	elseif col.key == "size" or col.key == "mtime" then
		return "DockyardMuted"
	end
end

local function build_rows()
	local rows = {}
	if state.path ~= "/" then
		table.insert(rows, {
			icon = icons.icon("directory"),
			name = "..",
			size = "",
			mtime = "",
			type = "directory",
			_item = { name = "..", type = "directory", _parent = true },
		})
	end
	for _, e in ipairs(state.entries or {}) do
		if state.show_hidden or e.name:sub(1, 1) ~= "." then
			local marker = e.type == "directory" and "/" or ""
			local name = e.name .. marker
			if e.target then
				name = name .. " -> " .. e.target
			end
			table.insert(rows, {
				icon = icons.icon(e.type),
				name = name,
				size = e.type == "directory" and "" or format_size(e.size),
				mtime = e.mtime or "",
				type = e.type,
				_item = e,
			})
		end
	end
	return rows
end

local function render()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	local width = vim.api.nvim_win_get_width(0)
	local header_lines = { ("# %s : %s"):format(state.container, state.path), "" }

	local body_lines, line_map, body_spans = table_view.render({
		width = width,
		margin = 1,
		columns = {
			{ key = "icon", name = "", width = 2 },
			{ key = "name", name = "Name", min_width = 30 },
			{ key = "size", name = "Size", width = 8 },
			{ key = "mtime", name = "Modified", min_width = 16, grow_last = true },
		},
		rows = build_rows(),
		cell_hl = row_hl,
	})

	for _, sp in ipairs(body_spans) do
		sp.line = sp.line + #header_lines
	end
	table.insert(body_spans, 1, { line = 0, start_col = 0, end_col = #header_lines[1], hl_group = "DockyardMuted" })

	local lines = {}
	for _, l in ipairs(header_lines) do
		table.insert(lines, l)
	end
	for _, l in ipairs(body_lines) do
		table.insert(lines, l)
	end

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.bo[state.buf].modified = false

	ui_utils.apply_spans(state.buf, body_spans)

	local shifted = {}
	for lnum, row in pairs(line_map) do
		shifted[lnum + #header_lines] = row
	end
	state.line_map = shifted
end

local function current_entry()
	if not state.line_map then
		return nil
	end
	local row = vim.api.nvim_win_get_cursor(0)[1]
	return state.line_map[row]
end

function M.refresh()
	core.list(state.container, state.path, function(res)
		if not res.ok then
			notify(res.error or "list failed", vim.log.levels.ERROR)
			state.entries = {}
		else
			state.entries = res.entries
		end
		render()
	end)
end

local function navigate(new_path)
	state.path = core.normalize(new_path)
	M.refresh()
end

local function abs_path_of(name)
	if state.path == "/" then
		return "/" .. name
	end
	return state.path .. "/" .. name
end

local function go_up()
	if state.path == "/" then
		return
	end
	navigate(core.dirname(state.path))
end

local function activate()
	local entry = current_entry()
	if not entry then
		return
	end
	if entry._parent then
		return go_up()
	end
	local target = abs_path_of(entry.name)
	if entry.type == "directory" then
		navigate(target)
		return
	end
	if entry.kind ~= "f" and entry.kind ~= "l" then
		notify("Not a regular file: " .. entry.name, vim.log.levels.WARN)
		return
	end
	M.open_file(state.container, target)
end

function M.open_file(container, path)
	core.read(container, path, function(res)
		if not res.ok then
			notify(res.error or "read failed", vim.log.levels.ERROR)
			return
		end
		local name = ("dockyard://%s%s"):format(container, path)
		local buf = vim.fn.bufnr(name)
		if buf == -1 then
			buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf, name)
			vim.bo[buf].buftype = "acwrite"
			vim.bo[buf].bufhidden = "wipe"
			vim.bo[buf].swapfile = false

			vim.api.nvim_create_autocmd("BufWriteCmd", {
				buffer = buf,
				callback = function()
					local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
					core.write(container, path, lines, function(w)
						if not w.ok then
							notify(w.error or "write failed", vim.log.levels.ERROR)
							return
						end
						vim.bo[buf].modified = false
						notify("Saved " .. container .. ":" .. path)
					end)
				end,
			})
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, res.lines)
		vim.bo[buf].modified = false
		local ft = vim.filetype.match({ filename = path })
		if ft then
			vim.bo[buf].filetype = ft
		end
		vim.cmd("vsplit")
		vim.api.nvim_set_current_buf(buf)
	end)
end

local function toggle_hidden()
	state.show_hidden = not state.show_hidden
	render()
end

local function yank_path()
	local entry = current_entry()
	if not entry then
		return
	end
	local p = entry._parent and core.dirname(state.path) or abs_path_of(entry.name)
	vim.fn.setreg("+", p)
	vim.fn.setreg('"', p)
	notify("Yanked " .. p)
end

local function confirm(prompt, cb)
	vim.ui.input({ prompt = prompt .. " [y/N]: " }, function(input)
		local answer = input and vim.trim(input):lower() or ""
		cb(answer == "y" or answer == "yes")
	end)
end

local function delete()
	local entry = current_entry()
	if not entry or entry._parent then
		return
	end
	local target = abs_path_of(entry.name)
	local kind = entry.type == "directory" and "directory" or "file"
	confirm(("Delete %s %s ?"):format(kind, target), function(ok)
		if not ok then
			return
		end
		core.rm(state.container, target, function(res)
			if not res.ok then
				return notify(res.error or "rm failed", vim.log.levels.ERROR)
			end
			notify("Deleted " .. target)
			M.refresh()
		end)
	end)
end

local function rename()
	local entry = current_entry()
	if not entry or entry._parent then
		return
	end
	vim.ui.input({ prompt = "Rename to: ", default = entry.name }, function(new_name)
		if not new_name or new_name == "" or new_name == entry.name then
			return
		end
		core.mv(state.container, abs_path_of(entry.name), abs_path_of(new_name), function(res)
			if not res.ok then
				return notify(res.error or "mv failed", vim.log.levels.ERROR)
			end
			notify(("Renamed %s -> %s"):format(entry.name, new_name))
			M.refresh()
		end)
	end)
end

local function create()
	vim.ui.input({ prompt = "Create (suffix / for dir): " }, function(name)
		if not name or name == "" then
			return
		end
		local is_dir = name:sub(-1) == "/"
		local clean = is_dir and name:sub(1, -2) or name
		local target = abs_path_of(clean)
		local fn = is_dir and core.mkdir or function(c, p, cb)
			core.write(c, p, {}, cb)
		end
		fn(state.container, target, function(res)
			if not res.ok then
				return notify(res.error or "create failed", vim.log.levels.ERROR)
			end
			notify("Created " .. target)
			M.refresh()
		end)
	end)
end

local function search()
	vim.ui.input({ prompt = "find -name pattern: " }, function(pattern)
		if not pattern or pattern == "" then
			return
		end
		core.find(state.container, state.path, pattern, function(res)
			if not res.ok then
				notify(res.error or "find failed", vim.log.levels.ERROR)
				return
			end
			local qf = {}
			for _, p in ipairs(res.paths or {}) do
				table.insert(qf, { filename = ("dockyard://%s%s"):format(state.container, p), lnum = 1, text = p })
			end
			vim.fn.setqflist({}, " ", { title = "dockyard find " .. pattern, items = qf })
			vim.cmd("copen")
		end)
	end)
end

local function close()
	local win = vim.api.nvim_get_current_win()
	if state.origin_buf and vim.api.nvim_buf_is_valid(state.origin_buf) then
		vim.api.nvim_win_set_buf(win, state.origin_buf)
	end
	local buf = state.buf
	state.buf = nil
	state.line_map = nil
	state.entries = nil
	state.origin_buf = nil
	if buf then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
end

local function attach_keymaps(buf)
	local opts = { buffer = buf, silent = true, nowait = true }
	vim.keymap.set("n", "<CR>", activate, opts)
	vim.keymap.set("n", "l", activate, opts)
	vim.keymap.set("n", "-", go_up, opts)
	vim.keymap.set("n", "h", go_up, opts)
	vim.keymap.set("n", "R", M.refresh, opts)
	vim.keymap.set("n", "gh", toggle_hidden, opts)
	vim.keymap.set("n", "s", search, opts)
	vim.keymap.set("n", "y", yank_path, opts)
	vim.keymap.set("n", "d", delete, opts)
	vim.keymap.set("n", "r", rename, opts)
	vim.keymap.set("n", "a", create, opts)
	vim.keymap.set("n", "o", create, opts)
	vim.keymap.set("n", "q", close, opts)
end

---@param container string
---@param path string
---@param opts? { win?: integer }
function M.open(container, path, opts)
	opts = opts or {}
	path = core.normalize(path)

	local name = ("dockyard://%s"):format(container)
	local buf = vim.fn.bufnr(name)
	if buf == -1 then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, name)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].swapfile = false
		vim.bo[buf].filetype = "dockyard-files"
		attach_keymaps(buf)
	end

	state.buf = buf
	state.container = container
	state.path = path

	local target_win = opts.win or vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_win_get_buf(target_win)
	if cur_buf ~= buf then
		if vim.api.nvim_buf_is_valid(cur_buf) then
			state.origin_buf = cur_buf
		end
		vim.api.nvim_win_set_buf(target_win, buf)
	end

	vim.api.nvim_set_option_value("number", false, { win = target_win })
	vim.api.nvim_set_option_value("relativenumber", false, { win = target_win })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = target_win })
	vim.api.nvim_set_option_value("statuscolumn", "", { win = target_win })
	vim.api.nvim_set_option_value("foldcolumn", "0", { win = target_win })
	vim.api.nvim_set_option_value("wrap", false, { win = target_win })
	vim.api.nvim_set_option_value("cursorline", false, { win = target_win })
	vim.b[buf].snacks_indent = false
	vim.b[buf].snacks_scope = false
	vim.b[buf].miniindentscope_disable = true

	M.refresh()
	return buf
end

return M
