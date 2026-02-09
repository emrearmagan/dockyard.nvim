local state = require("dockyard.ui.state")
local config = require("dockyard.config")

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

	local logs_data = {} -- raw list of all parsed objects
	local buffer_to_data = {} -- line_num in buffer -> parsed object
	local follow = false
	local is_auto_scrolling = false
	local is_detaching = false
	local raw_mode = false
	local filter_pattern = nil
	local stream_buffer = ""
	local flush_timer = vim.loop.new_timer()

	-- Robust JSON/Text extractor
	local function extract_entries()
		local entries = {}
		while #stream_buffer > 0 do
			-- Skip leading whitespace/newlines for start detection
			local start_idx = stream_buffer:find("[^%s%c]")
			if not start_idx then 
				stream_buffer = ""
				break 
			end
			
			-- If leading noise exists, we might want to trim it or treat as text
			-- But usually we just want the real content
			local first_char = stream_buffer:sub(start_idx, start_idx)

			if first_char == "{" then
				-- Potential JSON
				local count = 0
				local in_string = false
				local escape = false
				local found = false
				
				for i = start_idx, #stream_buffer do
					local char = stream_buffer:sub(i, i)
					if not escape then
						if char == "\"" then 
							in_string = not in_string
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
				
				if not found then break end -- Incomplete JSON, wait for more data
			else
				-- Plain Text: Take until next newline OR next {
				local next_json = stream_buffer:find("{", start_idx)
				local next_newline = stream_buffer:find("\n", start_idx)
				
				local split_at = nil
				if next_json and next_newline then
					split_at = math.min(next_json, next_newline)
				else
					split_at = next_json or next_newline
				end
				
				if not split_at then
					-- No termination found yet. 
					-- If the buffer is getting long or we are flushing, take it all
					break 
				end
				
				local entry = stream_buffer:sub(start_idx, split_at - 1)
				-- If it was split by a newline, remove the newline too
				if stream_buffer:sub(split_at, split_at) == "\n" then
					stream_buffer = stream_buffer:sub(split_at + 1)
				else
					stream_buffer = stream_buffer:sub(split_at)
				end
				
				if entry:gsub("%s+", "") ~= "" then
					table.insert(entries, entry)
				end
			end
		end
		return entries
	end

	local function process_entry(entry_text, skip_ui)
		if not vim.api.nvim_buf_is_valid(buf) then return end
		
		local cleaned_text = entry_text:gsub("^[%s%c]*", ""):gsub("[%s%c]*$", "")
		if cleaned_text == "" then return end

		local parsed = nil
		-- Try Custom Parser
		if log_cfg.parser then
			local ok, res = pcall(log_cfg.parser, cleaned_text)
			if ok and res then parsed = res end
		end

		-- Internal JSON Fallback (No highlighting, per user request)
		if not parsed and (cleaned_text:sub(1,1) == "{" or log_cfg.format == "json") then
			local ok, res = pcall(vim.json.decode, cleaned_text)
			if ok and res then
				local msg = res.message or res.msg or res.log or cleaned_text
				local level = (res.level or "info"):upper()
				local ts = ""
				if res.timestamp then
					ts = tostring(res.timestamp):match("T(%d%d:%d%d:%d%d)") or tostring(res.timestamp):sub(1, 10)
					ts = ts .. " "
				end
				parsed = {
					row = string.format("%s[%s] %s", ts, level, msg),
					raw = cleaned_text,
					detail = cleaned_text
				}
			end
		end

		if not parsed then
			parsed = { row = "-", raw = cleaned_text }
		end
		
		parsed.raw = parsed.raw or cleaned_text
		table.insert(logs_data, parsed)
		
		local max = config.options.loglens.max_lines or 2000
		if #logs_data > max then table.remove(logs_data, 1) end

		if skip_ui then return end

		local display_line = raw_mode and parsed.raw or (type(parsed.row) == "function" and parsed.row() or parsed.row)
		display_line = tostring(display_line):gsub("\n", " ")
		
		if filter_pattern and not display_line:lower():find(filter_pattern:lower(), 1, true) then
			return
		end

		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		local line_count = vim.api.nvim_buf_line_count(buf)
		local is_empty = line_count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
		
		if is_empty then
			vim.api.nvim_buf_set_lines(buf, 0, 1, false, { display_line })
		else
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, { display_line })
		end
		
		local new_lnum = vim.api.nvim_buf_line_count(buf) - 1
		buffer_to_data[new_lnum] = parsed

		if parsed.highlight and not raw_mode then
			parsed.highlight(buf, new_lnum)
		end

		if line_count > max then
			vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
			local new_b2d = {}
			for k, v in pairs(buffer_to_data) do
				if k > 0 then new_b2d[k-1] = v end
			end
			buffer_to_data = new_b2d
		end
		vim.api.nvim_buf_set_option(buf, "modifiable", false)

		if follow then
			is_auto_scrolling = true
			pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
			is_auto_scrolling = false
		end
	end

	local function flush_remaining()
		if #stream_buffer > 0 then
			local entry = stream_buffer
			stream_buffer = ""
			process_entry(entry)
		end
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

	local function redraw_all()
		if not vim.api.nvim_buf_is_valid(buf) then return end
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		local display_lines = {}
		buffer_to_data = {}
		local current_lnum = 0
		for _, parsed in ipairs(logs_data) do
			local line = raw_mode and parsed.raw or (type(parsed.row) == "function" and parsed.row() or parsed.row)
			line = tostring(line):gsub("\n", " ")
			if not filter_pattern or line:lower():find(filter_pattern:lower(), 1, true) then
				table.insert(display_lines, line)
				buffer_to_data[current_lnum] = parsed
				current_lnum = current_lnum + 1
			end
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
		if not raw_mode then
			for lnum, parsed in pairs(buffer_to_data) do
				if parsed.highlight then parsed.highlight(buf, lnum) end
			end
		end
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
	end

	local function open_detail(force_raw)
		local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
		local data = buffer_to_data[lnum]
		if not data then return end

		local show_raw = force_raw
		if show_raw == nil then show_raw = raw_mode end

		local dbuf = vim.api.nvim_create_buf(false, true)
		
		local function render_popup()
			local content
			if show_raw then
				content = data.raw
			else
				-- Try dedicated detail parser first (lazy execution)
				if log_cfg.detail_parser then
					local ok, res = pcall(log_cfg.detail_parser, data.raw)
					if ok and res then
						content = res
					end
				end

				-- Fallback to data.detail (if returned by main parser) or raw
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
			if show_raw or (content[1] and content[1]:match("^%s*{")) then
				ft = "json"
			end
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
			local title = show_raw and " Log Source (Raw) " or " Log Details (Parsed) "
			vim.api.nvim_win_set_config(dwin, { title = title })
		end, dopts)

		vim.keymap.set("n", "y", function()
			local lines = vim.api.nvim_buf_get_lines(dbuf, 0, -1, false)
			vim.fn.setreg("+", table.concat(lines, "\n"))
			vim.notify("Dockyard: Copied to clipboard")
		end, dopts)
	end

	-- Keymaps
	local kopts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end, kopts)

	vim.keymap.set("n", "R", function() 
		raw_mode = not raw_mode
		redraw_all()
		vim.notify("Dockyard: Global Raw Mode " .. (raw_mode and "ON" or "OFF"))
	end, kopts)

	vim.keymap.set("n", "f", function() follow = not follow; vim.notify("Dockyard: Follow " .. (follow and "ON" or "OFF")) end, kopts)
	vim.keymap.set("n", "/", function()
		vim.ui.input({ prompt = "Filter logs: " }, function(input)
			if input == nil then return end
			filter_pattern = input ~= "" and input or nil
			redraw_all()
		end)
	end, kopts)
	vim.keymap.set("n", "c", function() filter_pattern = nil; redraw_all(); vim.notify("Dockyard: Filter cleared") end, kopts)
	
	vim.keymap.set("n", "r", function() open_detail(true) end, kopts)
	vim.keymap.set("n", "o", function() open_detail(false) end, kopts)
	vim.keymap.set("n", "<cr>", function() open_detail(false) end, kopts)

	-- Auto-follow logic
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = buf,
		callback = function()
			if is_auto_scrolling then return end
			local ok, lnum = pcall(function() return vim.api.nvim_win_get_cursor(win)[1] end)
			if not ok then return end
			local line_count = vim.api.nvim_buf_line_count(buf)
			if lnum < line_count then
				if follow then
					follow = false
				end
			elseif lnum == line_count then
				if not follow then
					follow = true
				end
			end
		end
	})

	-- Job
	local cmd = log_cfg.type == "file" 
		and { "docker", "exec", container_id, "tail", "-n", "100", "-f", log_cfg.path }
		or { "docker", "logs", "-f", "--tail", "100", container_id }

	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			if data then 
				handle_incoming_chunk(table.concat(data, "\n"))
			end
		end,
		on_exit = function() flush_remaining() end,
	})

	vim.api.nvim_buf_attach(buf, false, {
		on_detach = function() 
			is_detaching = true
			if flush_timer then
				flush_timer:stop()
				if not flush_timer:is_closing() then flush_timer:close() end
			end
			flush_remaining() 
			vim.fn.jobstop(job_id) 
		end
	})
end

return M
