local M = {}

local popup_seq = 0

local function clamp_span(line, span)
	local line_len = #line
	local start_col = math.max(0, math.min(span.start_col or 0, line_len))
	local end_col = span.end_col
	if end_col == nil or end_col < 0 then
		end_col = line_len
	else
		end_col = math.max(start_col, math.min(end_col, line_len))
	end
	return start_col, end_col
end

local function popup_layout()
	local w = vim.o.columns
	local h = vim.o.lines
	local ww = math.max(math.floor(w * 0.62), 72)
	local wh = math.max(math.floor(h * 0.8), 20)
	local row = math.floor((h - wh) / 2)
	local col = math.floor((w - ww) / 2)
	return ww, wh, row, col
end

function M.create(opts)
	opts = opts or {}
	popup_seq = popup_seq + 1

	local state = {
		id = popup_seq,
		title = opts.title or " Popup ",
		footer = opts.footer,
		view = opts.view or "default",
		buf = nil,
		win = nil,
		ns = vim.api.nvim_create_namespace("dockyard.popup." .. tostring(popup_seq)),
		on_resize = opts.on_resize,
		on_close = opts.on_close,
	}

	local resize_group = vim.api.nvim_create_augroup("DockyardPopupResize" .. tostring(state.id), { clear = true })

	local function is_open()
		return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
	end

	local function ensure_buf()
		if state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf) then
			return state.buf
		end

		state.buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
		vim.api.nvim_set_option_value("swapfile", false, { buf = state.buf })
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
		vim.api.nvim_set_option_value("filetype", "dockyard_popup", { buf = state.buf })
		vim.b[state.buf].dockyard_popup_view = state.view

		vim.api.nvim_create_autocmd("BufWipeout", {
			buffer = state.buf,
			once = true,
			callback = function()
				state.buf = nil
				state.win = nil
				if type(state.on_close) == "function" then
					state.on_close()
				end
			end,
		})

		return state.buf
	end

	local function apply_win_style(win)
		vim.api.nvim_set_option_value("winhighlight", "", { win = win })
		vim.api.nvim_set_option_value("wrap", false, { win = win })
		vim.api.nvim_set_option_value("cursorline", false, { win = win })
	end

	local function recenter()
		if not is_open() then
			return
		end
		local ww, wh, row, col = popup_layout()
		vim.api.nvim_win_set_config(state.win, {
			relative = "editor",
			width = ww,
			height = wh,
			row = row,
			col = col,
			title = state.title,
			title_pos = "center",
			footer = state.footer,
			footer_pos = "center",
			zindex = 250,
		})
		if type(state.on_resize) == "function" then
			state.on_resize(state.win, state.buf)
		end
	end

	local function close()
		if is_open() then
			vim.api.nvim_win_close(state.win, true)
		end
		state.win = nil
		if type(state.on_close) == "function" then
			state.on_close()
		end
	end

	local function open(open_opts)
		open_opts = open_opts or {}
		if open_opts.title ~= nil then
			state.title = open_opts.title
		end
		if open_opts.footer ~= nil then
			state.footer = open_opts.footer
		end
		if open_opts.view ~= nil then
			state.view = open_opts.view
		end

		local buf = ensure_buf()
		vim.b[buf].dockyard_popup_view = state.view
		local ww, wh, row, col = popup_layout()

		if is_open() then
			vim.api.nvim_win_set_config(state.win, {
				relative = "editor",
				width = ww,
				height = wh,
				row = row,
				col = col,
				zindex = 250,
				title = state.title,
				title_pos = "center",
				footer = state.footer,
				footer_pos = "center",
			})
			vim.api.nvim_set_current_win(state.win)
		else
			state.win = vim.api.nvim_open_win(buf, true, {
				relative = "editor",
				width = ww,
				height = wh,
				row = row,
				col = col,
				style = "minimal",
				border = "rounded",
				title = state.title,
				title_pos = "center",
				footer = state.footer,
				footer_pos = "center",
				zindex = 250,
			})
		end

		apply_win_style(state.win)
		local map_opts = { buffer = buf, nowait = true, silent = true }
		vim.keymap.set("n", "q", close, map_opts)
		vim.keymap.set("n", "<Esc>", close, map_opts)
		return state.win, buf
	end

	local function set_content(lines, spans)
		if state.buf == nil or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
		vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines or {})
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })

		vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
		for _, span in ipairs(spans or {}) do
			local line = vim.api.nvim_buf_get_lines(state.buf, span.line, span.line + 1, false)[1] or ""
			local start_col, end_col = clamp_span(line, span)
			if end_col > start_col and span.hl_group then
				vim.api.nvim_buf_set_extmark(state.buf, state.ns, span.line, start_col, {
					end_row = span.line,
					end_col = end_col,
					hl_group = span.hl_group,
				})
			end
		end
	end

	vim.api.nvim_create_autocmd("VimResized", {
		group = resize_group,
		callback = recenter,
	})

	return {
		open = open,
		close = close,
		recenter = recenter,
		set_content = set_content,
		is_open = is_open,
		get_win = function()
			return state.win
		end,
		get_buf = function()
			return state.buf
		end,
		get_width = function()
			if is_open() then
				return vim.api.nvim_win_get_width(state.win)
			end
			return vim.o.columns
		end,
	}
end

return M
