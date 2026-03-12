local M = {}

---@param buf number
---@param state LogLensState
---@param handlers { close: fun(), refresh: fun(), open_detail: fun() }
function M.attach(buf, state, handlers)
	local opts = { buffer = buf, silent = true, nowait = true }

	vim.keymap.set("n", "q", function()
		handlers.close()
	end, opts)

	vim.keymap.set("n", "f", function()
		state.follow = not state.follow
		handlers.refresh()
	end, opts)

	vim.keymap.set("n", "r", function()
		state.raw = not state.raw
		handlers.refresh()
	end, opts)

	vim.keymap.set("n", "/", function()
		vim.ui.input({
			prompt = "Filter logs: ",
			default = state.filter or "",
		}, function(input)
			if input == nil then
				return
			end

			if input == "" then
				state.filter = nil
			else
				state.filter = input
			end

			handlers.refresh()
		end)
	end, opts)

	vim.keymap.set("n", "c", function()
		if state.filter ~= nil then
			state.filter = nil
			handlers.refresh()
		end
	end, opts)

	vim.keymap.set("n", "<CR>", function()
		handlers.open_detail()
	end, opts)

	vim.keymap.set("n", "K", function()
		handlers.open_detail()
	end, opts)

	local group = vim.api.nvim_create_augroup("DockyardLogLensFollow" .. tostring(buf), { clear = true })
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = buf,
		callback = function()
			if not state.follow then
				return
			end
			local line = vim.api.nvim_win_get_cursor(0)[1]
			local last = vim.api.nvim_buf_line_count(buf)
			-- Only disable follow when user moved away from bottom.
			if line < last then
				state.follow = false
				handlers.refresh()
			end
		end,
	})
end

return M
