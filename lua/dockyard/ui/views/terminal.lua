-- TODO: Add support for native terminal buffers as well, but toggleterm is the most popular and has a good API for this

local M = {}

-- One Sessions per container. Those are for reference
local toggleterm_sessions = {}
local float_session = nil

local function build_exec_cmd(container_id, shell)
	shell = shell or "sh"
	return string.format("docker exec -it %s %s", container_id, shell)
end

local function is_valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function focus_term_if_open(term)
	if term == nil then
		return false
	end
	if not is_valid_win(term.window) then
		return false
	end

	vim.api.nvim_set_current_win(term.window)
	vim.cmd("startinsert")
	return true
end

local function open_panel_terminal(Terminal, container_id, shell)
	if float_session ~= nil and float_session.container_id ~= container_id then
		pcall(function()
			float_session.term:close()
		end)
		float_session = nil
	end

	if float_session == nil then
		local ok_new, term = pcall(Terminal.new, Terminal, {
			cmd = build_exec_cmd(container_id, shell),
			direction = "float",
			hidden = true,
			close_on_exit = true,
			float_opts = {
				border = "curved",
				zindex = 260,
				width = math.floor(vim.o.columns * 0.7),
				height = math.floor(vim.o.lines * 0.5),
			},
			on_open = function()
				vim.cmd("startinsert")
			end,
			on_exit = function(t)
				vim.schedule(function()
					if t ~= nil and is_valid_win(t.window) then
						pcall(vim.api.nvim_win_close, t.window, true)
					end
				end)
				float_session = nil
			end,
		})
		if not ok_new then
			vim.notify("Dockyard: failed to create toggleterm session", vim.log.levels.ERROR)
			return false
		end

		float_session = {
			container_id = container_id,
			term = term,
		}
	end

	if focus_term_if_open(float_session.term) then
		return true
	end

	local ok_open = pcall(function()
		float_session.term:open()
	end)
	if not ok_open then
		vim.notify("Dockyard: failed to open toggleterm session", vim.log.levels.ERROR)
		return false
	end

	return true
end

local function open_full_terminal(Terminal, container_id, shell, target_win)
	local session = toggleterm_sessions[container_id]
	if session == nil then
		local ok_new, new_session = pcall(Terminal.new, Terminal, {
			cmd = build_exec_cmd(container_id, shell),
			direction = "horizontal",
			hidden = true,
			close_on_exit = true,
			size = 15,
			on_open = function()
				vim.cmd("startinsert")
			end,
			on_exit = function(t)
				vim.schedule(function()
					if t ~= nil and is_valid_win(t.window) then
						pcall(vim.api.nvim_win_close, t.window, true)
					end
				end)
				toggleterm_sessions[container_id] = nil
			end,
		})
		if not ok_new then
			vim.notify("Dockyard: failed to create toggleterm session", vim.log.levels.ERROR)
			return false
		end

		session = new_session
		toggleterm_sessions[container_id] = session
	end

	if focus_term_if_open(session) then
		return true
	end

	local ok_open = pcall(function()
		if is_valid_win(target_win) then
			vim.api.nvim_set_current_win(target_win)
		end
		session:open()
	end)
	if not ok_open then
		vim.notify("Dockyard: failed to open toggleterm session", vim.log.levels.ERROR)
		return false
	end

	return true
end

-- ----------------------------
-- Toggleterm backend
-- ----------------------------
local function open_with_toggleterm(container_id, shell, ctx)
	local ok, mod = pcall(require, "toggleterm.terminal")
	if not ok then
		return false
	end

	local Terminal = mod.Terminal
	local mode = (ctx and ctx.mode) or "panel"
	local target_win = ctx and ctx.win

	if mode == "panel" then
		return open_panel_terminal(Terminal, container_id, shell)
	end

	if mode == "full" then
		return open_full_terminal(Terminal, container_id, shell, target_win)
	end

	return false
end

function M.open(container_id, shell, ctx)
	if container_id == nil or container_id == "" then
		vim.notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end

	if open_with_toggleterm(container_id, shell, ctx) then
		return
	end

	vim.notify("Dockyard: toggleterm not found or failed", vim.log.levels.WARN)
end

return M
