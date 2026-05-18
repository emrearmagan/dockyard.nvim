local M = {}

---@class DockyardHelpKeyItem
---@field key string|string[]
---@field desc string
---@field callback? function|string
---@field mode? string|string[]
---@field opts? table
---@field hidden? boolean
---@field index? number

---@class DockyardHelpCommandItem
---@field name string
---@field desc string
---@field callback? function|string
---@field opts? table
---@field hidden? boolean
---@field index? number

---@class DockyardHelpGroupOpts
---@field buffer integer
---@field index? number

---@class DockyardHelpToggleOpts
---@field buffer? integer

local state = {
	buffers = {},
	ui = {
		visible = false,
		win_id = nil,
		buf_id = nil,
		target_bufnr = nil,
		autocmds = {},
		on_key_ns = nil,
	},
}

local DEFAULT_INDEX = 100
local KEY_SEPARATOR = " / "
local ITEM_MARKER = " ▸ "
local NUM_COLUMNS = 4
local ns = vim.api.nvim_create_namespace("dockyard.help")
local resize_group = vim.api.nvim_create_augroup("DockyardHelpPopupResize", { clear = true })

---@param bufnr integer
local function ensure_state(bufnr)
	if not state.buffers[bufnr] then
		state.buffers[bufnr] = {
			keys = {},
			commands = {},
			group_opts = {},
		}

		vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = bufnr,
			callback = function()
				state.buffers[bufnr] = nil
			end,
			once = true,
		})
	end
	return state.buffers[bufnr]
end

---@param opts table?
---@param source string
---@return integer
local function require_buffer(opts, source)
	local bufnr = opts and opts.buffer
	if not bufnr or type(bufnr) ~= "number" then
		error(source .. ": opts.buffer is required")
	end
	return bufnr
end

---@param key string|string[]
---@return string[]
local function normalize_keys(key)
	if type(key) == "table" then
		return key
	end
	return { key }
end

---@param list table[]
---@param field string
---@param value string
local function remove_existing_entry(list, field, value)
	for i, existing in ipairs(list) do
		if existing[field] == value then
			table.remove(list, i)
			return
		end
	end
end

---@param group string
---@param items DockyardHelpKeyItem[]
---@param opts DockyardHelpGroupOpts
function M.register(group, items, opts)
	local bufnr = require_buffer(opts, "help.register")

	local bstate = ensure_state(bufnr)
	if not bstate.keys[group] then
		bstate.keys[group] = {}
		bstate.group_opts[group] = bstate.group_opts[group] or {}
	end

	if opts.index then
		bstate.group_opts[group].index = opts.index
	end

	for _, item in ipairs(items) do
		local mode = item.mode or "n"
		local key_opts = vim.tbl_extend("force", {}, item.opts or {})
		key_opts.buffer = bufnr
		key_opts.desc = item.desc
		if key_opts.silent == nil then
			key_opts.silent = true
		end
		if key_opts.nowait == nil then
			key_opts.nowait = true
		end

		local keys = normalize_keys(item.key)

		if item.callback then
			for _, k in ipairs(keys) do
				vim.keymap.set(mode, k, item.callback, key_opts)
			end
		end

		if not item.hidden then
			local display_key = table.concat(keys, KEY_SEPARATOR)
			remove_existing_entry(bstate.keys[group], "key", display_key)

			table.insert(bstate.keys[group], {
				key = display_key,
				desc = item.desc,
				mode = mode,
				index = item.index or DEFAULT_INDEX,
			})
		end
	end
end

---@param group string
---@param items DockyardHelpCommandItem[]
---@param opts DockyardHelpGroupOpts
function M.register_command(group, items, opts)
	local bufnr = require_buffer(opts, "help.register_command")

	local bstate = ensure_state(bufnr)
	if not bstate.commands[group] then
		bstate.commands[group] = {}
		bstate.group_opts[group] = bstate.group_opts[group] or {}
	end

	if opts.index then
		bstate.group_opts[group].index = opts.index
	end

	for _, item in ipairs(items) do
		local cmd_opts = vim.tbl_extend("force", {}, item.opts or {})
		cmd_opts.desc = item.desc

		if item.callback then
			vim.api.nvim_buf_create_user_command(bufnr, item.name, item.callback, cmd_opts)
		end

		if not item.hidden then
			remove_existing_entry(bstate.commands[group], "name", item.name)

			table.insert(bstate.commands[group], {
				name = item.name,
				desc = item.desc,
				index = item.index or DEFAULT_INDEX,
			})
		end
	end
end

---@param group string
---@param items { key: string|string[], mode?: string|string[] }[]
---@param opts DockyardHelpGroupOpts
function M.remove(group, items, opts)
	local bufnr = require_buffer(opts, "help.remove")
	local bstate = state.buffers[bufnr]
	if not bstate or not bstate.keys[group] then
		return
	end

	for _, item in ipairs(items) do
		local mode = item.mode or "n"
		local keys = normalize_keys(item.key)

		for _, key in ipairs(keys) do
			pcall(vim.keymap.del, mode, key, { buffer = bufnr })
		end

		local display_key = table.concat(keys, KEY_SEPARATOR)
		remove_existing_entry(bstate.keys[group], "key", display_key)
	end

	if #bstate.keys[group] == 0 then
		bstate.keys[group] = nil
		if not bstate.commands[group] then
			bstate.group_opts[group] = nil
		end
	end
end

---@param bstate table
---@param group_name string
---@return number
local function group_index(bstate, group_name)
	local opts = bstate.group_opts[group_name]
	return (opts and opts.index) or DEFAULT_INDEX
end

---@param group table
---@param item table
---@return string
local function group_item_left(group, item)
	return group.is_cmd and item.name or item.key
end

---@param bstate table
---@return table[]
local function collect_all_groups(bstate)
	local all_groups = {}

	for group_name, items in pairs(bstate.keys) do
		table.insert(all_groups, {
			name = group_name,
			items = items,
			is_cmd = false,
			index = group_index(bstate, group_name),
		})
	end

	for group_name, items in pairs(bstate.commands) do
		table.insert(all_groups, {
			name = group_name,
			items = items,
			is_cmd = true,
			index = group_index(bstate, group_name),
		})
	end

	table.sort(all_groups, function(a, b)
		if a.index == b.index then
			return a.name < b.name
		end
		return a.index < b.index
	end)

	return all_groups
end

---@param all_groups table[]
---@return table[]
local function collect_valid_groups(all_groups)
	local valid_groups = {}

	for _, group in ipairs(all_groups) do
		if #group.items > 0 then
			table.sort(group.items, function(a, b)
				if a.index == b.index then
					return group_item_left(group, a) < group_item_left(group, b)
				end
				return a.index < b.index
			end)
			table.insert(valid_groups, group)
		end
	end

	return valid_groups
end

---@param valid_groups table[]
---@return table[]
local function build_render_items(valid_groups)
	local out = {}
	for gi, group in ipairs(valid_groups) do
		local max_left = 0
		for _, item in ipairs(group.items) do
			local left = group_item_left(group, item)
			if #left > max_left then
				max_left = #left
			end
		end

		table.insert(out, { type = "header", text = group.name })
		for _, item in ipairs(group.items) do
			table.insert(out, {
				type = "item",
				left = group_item_left(group, item),
				right = item.desc,
				max_left = max_left,
			})
		end

		if gi < #valid_groups then
			table.insert(out, { type = "empty" })
		end
	end
	return out
end

---Build a bottom-strip layout with items packed across NUM_COLUMNS columns.
---@param bufnr integer
---@param max_width integer
---@return { lines: string[], spans: table[], height: integer }
local function get_layout(bufnr, max_width)
	local bstate = state.buffers[bufnr]
	if not bstate then
		return { lines = { "  No bindings registered  " }, spans = {}, height = 1 }
	end

	local valid_groups = collect_valid_groups(collect_all_groups(bstate))
	if #valid_groups == 0 then
		return { lines = { "  No bindings registered  " }, spans = {}, height = 1 }
	end

	local lines = { "" }
	local spans = {}
	local height = 1

	-- Find the widest item across all groups so columns are uniform.
	local widest_item = 0
	for _, group in ipairs(valid_groups) do
		local max_left = 0
		for _, item in ipairs(group.items) do
			local left = group_item_left(group, item)
			if #left > max_left then
				max_left = #left
			end
		end
		for _, item in ipairs(group.items) do
			local w = max_left + #ITEM_MARKER + #item.desc
			if w > widest_item then
				widest_item = w
			end
		end
	end

	-- col_width = widest item + leading "  " + trailing pad. Min 1 column.
	local col_width = widest_item + 4
	local num_cols = math.max(1, math.min(NUM_COLUMNS, math.floor(max_width / col_width)))
	col_width = math.floor(max_width / num_cols)

	local current_line = ""
	local line_idx = 1
	local col_idx = 0

	local function flush_line()
		if current_line ~= "" then
			table.insert(lines, current_line)
			height = height + 1
			line_idx = line_idx + 1
			current_line = ""
			col_idx = 0
		end
	end

	local function add_empty_line()
		table.insert(lines, "")
		height = height + 1
		line_idx = line_idx + 1
		col_idx = 0
	end

	for _, render_item in ipairs(build_render_items(valid_groups)) do
		if render_item.type == "empty" then
			flush_line()
			add_empty_line()
		elseif render_item.type == "header" then
			if current_line ~= "" then
				flush_line()
			end
			local txt = render_item.text
			table.insert(spans, {
				line = line_idx,
				start_col = 2,
				end_col = 2 + #txt,
				hl_group = "DockyardColumnHeader",
			})
			current_line = "  " .. txt
			flush_line()
		else
			if col_idx >= num_cols then
				flush_line()
			end

			local left_str = render_item.left
			local right_str = ITEM_MARKER .. render_item.right
			local right_pad = render_item.max_left - #left_str
			local padded_left = left_str .. string.rep(" ", right_pad)

			local display = padded_left .. right_str
			local pad_len = col_width - #display - 2
			if pad_len < 0 then
				pad_len = 1
			end

			local start_col = #current_line + 2
			table.insert(spans, {
				line = line_idx,
				start_col = start_col,
				end_col = start_col + #left_str,
				hl_group = "DockyardHelpKey",
			})
			table.insert(spans, {
				line = line_idx,
				start_col = start_col + #padded_left,
				end_col = start_col + #padded_left + #right_str,
				hl_group = "DockyardMuted",
			})

			current_line = current_line .. "  " .. padded_left .. right_str .. string.rep(" ", pad_len)
			col_idx = col_idx + 1
		end
	end

	flush_line()
	if lines[#lines] ~= "" then
		add_empty_line()
	end

	return { lines = lines, spans = spans, height = height }
end

---@param buf integer
---@param spans table[]
local function apply_spans(buf, spans)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for _, span in ipairs(spans or {}) do
		local line_text = vim.api.nvim_buf_get_lines(buf, span.line, span.line + 1, false)[1] or ""
		local line_len = #line_text

		local start_col = math.max(0, math.min(span.start_col or 0, line_len))
		local end_col = span.end_col
		if end_col == nil or end_col < 0 then
			end_col = line_len
		else
			end_col = math.max(start_col, math.min(end_col, line_len))
		end

		if end_col > start_col and span.hl_group then
			vim.api.nvim_buf_set_extmark(buf, ns, span.line, start_col, {
				end_row = span.line,
				end_col = end_col,
				hl_group = span.hl_group,
			})
		end
	end
end

local function cleanup_ui()
	if state.ui.win_id and vim.api.nvim_win_is_valid(state.ui.win_id) then
		pcall(vim.api.nvim_win_close, state.ui.win_id, true)
	end
	if state.ui.buf_id and vim.api.nvim_buf_is_valid(state.ui.buf_id) then
		pcall(vim.api.nvim_buf_delete, state.ui.buf_id, { force = true })
	end

	for _, id in ipairs(state.ui.autocmds) do
		pcall(vim.api.nvim_del_autocmd, id)
	end

	if state.ui.on_key_ns then
		pcall(vim.on_key, nil, state.ui.on_key_ns)
	end

	state.ui.visible = false
	state.ui.win_id = nil
	state.ui.buf_id = nil
	state.ui.target_bufnr = nil
	state.ui.autocmds = {}
	state.ui.on_key_ns = nil
end

---@return boolean
function M.is_open()
	return state.ui.visible
end

---@param opts? DockyardHelpToggleOpts
function M.show(opts)
	opts = opts or {}
	local bufnr = opts.buffer or vim.api.nvim_get_current_buf()

	if state.ui.visible then
		cleanup_ui()
		return
	end

	local max_width = vim.o.columns
	local layout = get_layout(bufnr, max_width)
	if layout.height == 0 then
		return
	end

	local buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf_id })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf_id })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf_id })
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, layout.lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf_id })
	apply_spans(buf_id, layout.spans)

	local win_id = vim.api.nvim_open_win(buf_id, false, {
		relative = "editor",
		width = max_width,
		height = layout.height,
		col = 0,
		row = vim.o.lines - layout.height,
		style = "minimal",
		border = "none",
		zindex = 250,
		focusable = false,
	})
	vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat", { win = win_id })

	state.ui.visible = true
	state.ui.win_id = win_id
	state.ui.buf_id = buf_id
	state.ui.target_bufnr = bufnr

	-- Any keypress in the parent window dismisses the help strip.
	local on_key_ns = vim.api.nvim_create_namespace("dockyard_help_onkey")
	vim.on_key(function()
		if not state.ui.visible then
			return
		end
		vim.schedule(cleanup_ui)
	end, on_key_ns)
	state.ui.on_key_ns = on_key_ns

	local group = vim.api.nvim_create_augroup("DockyardHelpUI", { clear = true })
	local au_id = vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
		group = group,
		callback = function()
			if vim.api.nvim_get_current_win() ~= state.ui.win_id then
				cleanup_ui()
			end
		end,
	})
	table.insert(state.ui.autocmds, au_id)
end

---@param opts? DockyardHelpToggleOpts
function M.toggle(opts)
	if state.ui.visible then
		cleanup_ui()
	else
		M.show(opts)
	end
end

vim.api.nvim_create_autocmd("VimResized", {
	group = resize_group,
	callback = function()
		if state.ui.visible then
			cleanup_ui()
		end
	end,
})

return M
