local state = require("dockyard.ui.state")
local config = require("dockyard.config")
local parsers = require("dockyard.ui.parsers")

local M = {}

function M.show_menu(item)
	local container_name = item.name:gsub("^/", "")
	local log_configs = config.options.loglens.containers[container_name] or {}
	
	if #log_configs == 0 then
		M.open(item, {
			name = "Docker Logs",
			type = "docker",
		})
		return
	end

	if #log_configs == 1 then
		M.open(item, log_configs[1])
		return
	end

	local menu_items = {}
	for _, cfg in ipairs(log_configs) do
		table.insert(menu_items, cfg.name)
	end

	vim.ui.select(menu_items, {
		prompt = "Select Log Source for " .. container_name .. ":",
	}, function(choice)
		if not choice then return end
		for _, cfg in ipairs(log_configs) do
			if cfg.name == choice then
				M.open(item, cfg)
				break
			end
		end
	end)
end

function M.open(item, log_cfg)
	local container_id = item.id
	local container_name = item.name:gsub("^/", "")
	
	local name = string.format("dockyard-logs-%s-%s", container_name, log_cfg.name:gsub("%s+", "-"):lower())
	
	-- Check if buffer already exists and is valid
	local existing_buf = vim.fn.bufnr(name)
	if existing_buf ~= -1 and vim.api.nvim_buf_is_valid(existing_buf) then
		-- If buffer exists but no window, open it
		local win_found = false
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(w) == existing_buf then
				vim.api.nvim_set_current_win(w)
				win_found = true
				break
			end
		end
		
		if not win_found then
			vim.cmd("belowright split")
			vim.api.nvim_win_set_buf(0, existing_buf)
		end
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "filetype", "dockyard_logs")

	vim.cmd("belowright split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)

	-- Window Options
	vim.api.nvim_win_set_option(win, "wrap", false)
	vim.api.nvim_win_set_option(win, "number", false)
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_option(win, "signcolumn", "no")
	vim.api.nvim_win_set_option(win, "foldcolumn", "0")
	vim.api.nvim_win_set_option(win, "cursorline", true)
	vim.api.nvim_win_set_option(win, "winhighlight", "CursorLine:DockyardCursorLine")

	local logs_data = {} -- raw list of all parsed objects
	local buffer_to_data = {} -- line_num in buffer -> parsed object
	local follow = true
	local is_auto_scrolling = false
	local is_detaching = false
	local raw_mode = false
	local filter_pattern = nil
	local stream_buffer = ""
	local flush_timer = vim.loop.new_timer()
	local render_queue = {}
	local render_timer = vim.loop.new_timer()
	local namespace = vim.api.nvim_create_namespace("dockyard_log_ui")

	local function draw()
		if not vim.api.nvim_buf_is_valid(buf) then return end
		local win_width = vim.api.nvim_win_get_width(win)

		-- 1. Sticky Header & Navbar (Winbar)
		local nav_items = {
			{ label = "󰌑 Details", hl = "DockyardAction" },
			{ label = "r Raw", hl = "DockyardAction" },
			{ label = "f Follow", hl = follow and "DockyardTabActive" or "DockyardTabInactive" },
			{ label = "/ Filter", hl = "DockyardAction" },
			{ label = "q Close", hl = "DockyardAction" },
		}

		local winbar_str = string.format("%%#DockyardHeader#    %s  %%#Normal# ", container_name)
		for _, item in ipairs(nav_items) do
			winbar_str = winbar_str .. string.format("%%#%s# %s %%#Normal# ", item.hl, item.label)
		end

		if filter_pattern then
			winbar_str = winbar_str .. "%%#DockyardTabActive# Filtered (c: Clear) %%#Normal#"
		end

		pcall(function() vim.wo[win].winbar = winbar_str end)

		-- 2. Table
		local final_lines = { "" } -- Add an empty line at the top for spacing
		local rows = {}
		for _, parsed in ipairs(logs_data) do
			local display_msg = raw_mode and parsed.raw or (type(parsed.row) == "function" and parsed.row() or parsed.row)
			display_msg = tostring(display_msg or "-"):gsub("\n", " ")
			
			if not filter_pattern or display_msg:lower():find(filter_pattern:lower(), 1, true) then
				table.insert(rows, {
					log = display_msg,
					_raw_parsed = parsed
				})
			end
		end

		local log_table_config = {
			columns = { { key = "log", label = "", min_width = 1, weight = 1 } }
		}

		local TableRenderer = require("dockyard.ui.table")
		local table_lines, _ = TableRenderer.render({
			config = log_table_config,
			rows = rows,
			width = win_width,
			margin = 0,
		})

		-- Skip Table Header and Spacer (lines 1 & 2)
		for i = 3, #table_lines do
			final_lines[#final_lines + 1] = table_lines[i]
		end

		-- 3. Set content
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)
		vim.api.nvim_buf_set_option(buf, "modifiable", false)

		-- 4. Apply Log Highlights
		local filtered_idx = 0
		for _, parsed in ipairs(logs_data) do
			local display_msg = raw_mode and parsed.raw or (type(parsed.row) == "function" and parsed.row() or parsed.row)
			if not filter_pattern or tostring(display_msg):lower():find(filter_pattern:lower(), 1, true) then
				local lnum = filtered_idx + 1 -- Offset by 1 for the empty line
				if parsed.highlight and not raw_mode then
					pcall(parsed.highlight, buf, lnum, 0)
				end
				filtered_idx = filtered_idx + 1
			end
		end

		-- 5. Sync buffer_to_data
		buffer_to_data = {}
		filtered_idx = 0
		for _, parsed in ipairs(logs_data) do
			local display_msg = raw_mode and parsed.raw or (type(parsed.row) == "function" and parsed.row() or parsed.row)
			if not filter_pattern or tostring(display_msg):lower():find(filter_pattern:lower(), 1, true) then
				buffer_to_data[filtered_idx + 1] = parsed -- Offset by 1
				filtered_idx = filtered_idx + 1
			end
		end

		if follow then
			is_auto_scrolling = true
			vim.api.nvim_win_set_cursor(win, { #final_lines, 0 })
			is_auto_scrolling = false
		end
	end

	local function flush_render_queue()
		if #render_queue == 0 or not vim.api.nvim_buf_is_valid(buf) then return end
		draw()
		render_queue = {}
	end

	local function extract_entries()
		local entries = {}
		while #stream_buffer > 0 do
			local start_idx = stream_buffer:find("[^%s%c]")
			if not start_idx then 
				stream_buffer = ""
				break 
			end
			local first_char = stream_buffer:sub(start_idx, start_idx)
			if first_char == "{" then
				local count = 0
				local in_string = false
				local escape = false
				local found = false
				for i = start_idx, #stream_buffer do
					local char = stream_buffer:sub(i, i)
					if not escape then
						if char == "\"" then in_string = not in_string
						elseif not in_string then
							if char == "{" then count = count + 1
							elseif char == "}" then 
								count = count - 1
								if count == 0 then
									table.insert(entries, stream_buffer:sub(start_idx, i))
									stream_buffer = stream_buffer:sub(i + 1)
									found = true
									break
								end
							end
						end
					end
					if char == "\\" then escape = not escape else escape = false end
				end
				if not found then break end
			else
				local next_json = stream_buffer:find("{", start_idx)
				local next_newline = stream_buffer:find("\n", start_idx)
				local split_at = next_json or next_newline
				if next_json and next_newline then split_at = math.min(next_json, next_newline) end
				if not split_at then break end
				local entry = stream_buffer:sub(start_idx, split_at - 1)
				if stream_buffer:sub(split_at, split_at) == "\n" then stream_buffer = stream_buffer:sub(split_at + 1)
				else stream_buffer = stream_buffer:sub(split_at) end
				if entry:gsub("%s+", "") ~= "" then table.insert(entries, entry) end
			end
		end
		return entries
	end

	local function process_entry(entry_text, skip_ui)
		if not vim.api.nvim_buf_is_valid(buf) then return end
		local cleaned_text = entry_text:gsub("^[%s%c]*", ""):gsub("[%s%c]*$", "")
		if cleaned_text == "" then return end
		local parsed = nil
		if log_cfg.parser then
			local ok, res = pcall(log_cfg.parser, cleaned_text)
			if ok and res then parsed = res end
		end
		if not parsed then
			if cleaned_text:sub(1,1) == "{" or log_cfg.format == "json" then
				parsed = parsers.json(cleaned_text)
			else
				parsed = parsers.text(cleaned_text)
			end
		end
		if not parsed then return end
		parsed.raw = parsed.raw or cleaned_text
		table.insert(logs_data, parsed)
		local max = config.options.loglens.max_lines or 2000
		if #logs_data > max then table.remove(logs_data, 1) end
		if skip_ui then return end
		table.insert(render_queue, parsed)
	end

	local function flush_remaining()
		if #stream_buffer > 0 then
			local entry = stream_buffer
			stream_buffer = ""
			process_entry(entry)
		end
		flush_render_queue()
	end

	local function handle_incoming_chunk(chunk)
		if not chunk or chunk == "" then return end
		if chunk:match("^[\1\2\3]%z%z%z") then chunk = chunk:sub(9) end
		stream_buffer = stream_buffer .. chunk
		local entries = extract_entries()
		for _, e in ipairs(entries) do process_entry(e) end
		if #stream_buffer > 0 then
			flush_timer:stop()
			flush_timer:start(300, 0, vim.schedule_wrap(function()
				if not is_detaching then
					local trimmed = stream_buffer:gsub("^%s+", "")
					if trimmed ~= "" and trimmed:sub(1,1) ~= "{" then flush_remaining() end
				end
			end))
		end
	end

	local function open_detail(force_raw)
		local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
		local data = buffer_to_data[lnum]
		if not data then return end
		local show_raw = force_raw or raw_mode
		local dbuf = vim.api.nvim_create_buf(false, true)
		local function render_popup()
			local content
			if show_raw then content = data.raw
			else
				if log_cfg.detail_parser then
					local ok, res = pcall(log_cfg.detail_parser, data.raw)
					if ok and res then content = res end
				end
				if not content then
					content = data.detail or data.raw
					if type(content) == "function" then content = content() end
				end
			end
			if type(content) == "string" then content = vim.split(content, "\n") end
			vim.api.nvim_buf_set_option(dbuf, "modifiable", true)
			vim.api.nvim_buf_set_lines(dbuf, 0, -1, false, content)
			vim.api.nvim_buf_set_option(dbuf, "modifiable", false)
			local ft = "text"
			if show_raw or (content[1] and content[1]:match("^%s*{")) then ft = "json" end
			vim.api.nvim_buf_set_option(dbuf, "filetype", ft)
		end
		render_popup()
		local w, h = vim.o.columns, vim.o.lines
		local win_w, win_h = math.floor(w * 0.8), math.floor(h * 0.7)
		local dwin = vim.api.nvim_open_win(dbuf, true, {
			relative = "editor", width = win_w, height = win_h,
			row = math.floor((h - win_h) / 2), col = math.floor((w - win_w) / 2),
			style = "minimal", border = "rounded", title = " Log Details (r: Toggle Raw, y: Copy) "
		})
		local dopts = { buffer = dbuf, nowait = true, silent = true }
		vim.keymap.set("n", "q", "<cmd>close<cr>", dopts)
		vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", dopts)
		vim.keymap.set("n", "o", "<cmd>close<cr>", dopts)
		vim.keymap.set("n", "r", function()
			show_raw = not show_raw
			render_popup()
			vim.api.nvim_win_set_config(dwin, { title = show_raw and " Log Source (Raw) " or " Log Details (Parsed) " })
		end, dopts)
		vim.keymap.set("n", "y", function()
			vim.fn.setreg("+", table.concat(vim.api.nvim_buf_get_lines(dbuf, 0, -1, false), "\n"))
			vim.notify("Dockyard: Copied to clipboard")
		end, dopts)
	end

	local kopts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", function() if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end end, kopts)
	vim.keymap.set("n", "R", function() raw_mode = not raw_mode; draw(); vim.notify("Dockyard: Global Raw Mode " .. (raw_mode and "ON" or "OFF")) end, kopts)
	vim.keymap.set("n", "f", function()
		follow = not follow
		if follow and vim.api.nvim_buf_is_valid(buf) then
			is_auto_scrolling = true
			pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
			is_auto_scrolling = false
		end
		draw()
	end, kopts)
	vim.keymap.set("n", "/", function()
		vim.ui.input({ prompt = "Filter logs: " }, function(input)
			if input == nil then return end
			filter_pattern = input ~= "" and input or nil
			draw()
		end)
	end, kopts)
	vim.keymap.set("n", "c", function() filter_pattern = nil; draw() end, kopts)
	vim.keymap.set("n", "r", function() open_detail(true) end, kopts)
	vim.keymap.set("n", "o", function() open_detail(false) end, kopts)
	vim.keymap.set("n", "<cr>", function() open_detail(false) end, kopts)

	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = buf,
		callback = function()
			if is_auto_scrolling then return end
			local ok, lnum = pcall(function() return vim.api.nvim_win_get_cursor(win)[1] end)
			if not ok then return end
			local line_count = vim.api.nvim_buf_line_count(buf)
			-- Only auto-disable follow when moving away from bottom.
			-- Do NOT auto-enable when reaching the bottom.
			if follow and lnum < line_count then 
				follow = false
				draw()
			end
		end
	})

	render_timer:start(100, 100, vim.schedule_wrap(function() if not is_detaching then flush_render_queue() end end))
	local cmd = log_cfg.type == "file" and { "docker", "exec", container_id, "tail", "-n", "100", "-f", log_cfg.path } or { "docker", "logs", "-f", "--tail", "100", container_id }
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data) if data then handle_incoming_chunk(table.concat(data, "\n")) end end,
		on_exit = function() flush_remaining() end,
	})

	vim.api.nvim_buf_attach(buf, false, {
		on_detach = function() 
			is_detaching = true
			if flush_timer then flush_timer:stop(); if not flush_timer:is_closing() then flush_timer:close() end end
			if render_timer then render_timer:stop(); if not render_timer:is_closing() then render_timer:close() end end
			flush_remaining(); vim.fn.jobstop(job_id) 
		end
	})
	draw()
end

return M
