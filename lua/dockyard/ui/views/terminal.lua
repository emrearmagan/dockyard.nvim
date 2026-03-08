-- TODO: Add support for native terminal buffers as well, but toggleterm is the most popular and has a good API for this

local M = {}
local ui_state = require("dockyard.ui.state")

-- One Sessions per container. Those are for reference
local toggleterm_sessions = {}

local function build_exec_cmd(container_id, shell)
	shell = shell or "sh"
	return string.format("docker exec -it %s %s", container_id, shell)
end

local function is_valid_win(win)
	return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function resolve_host_win(target_win)
	if is_valid_win(target_win) then
		local cfg = vim.api.nvim_win_get_config(target_win)
		if cfg.relative == "" then
			return target_win
		end
	end

	if is_valid_win(ui_state.prev_win) then
		return ui_state.prev_win
	end

	return vim.api.nvim_get_current_win()
end

-- ----------------------------
-- Toggleterm backend
-- ----------------------------
local function open_with_toggleterm(container_id, shell, target_win)
	local ok, mod = pcall(require, "toggleterm.terminal")
	if not ok then
		return false
	end

	local Terminal = mod.Terminal
	local direction = "horizontal"

	local session = toggleterm_sessions[container_id]
	if session ~= nil and session.direction ~= direction then
		pcall(function()
			session:close()
		end)
		session = nil
		toggleterm_sessions[container_id] = nil
	end

	if session == nil then
		local ok_new, new_session = pcall(Terminal.new, Terminal, {
			cmd = build_exec_cmd(container_id, shell),
			direction = direction,
			hidden = true,
			close_on_exit = false,
			size = 15,
			on_open = function()
				vim.cmd("startinsert")
			end,
		})
		if not ok_new then
			vim.notify("Dockyard: failed to create toggleterm session", vim.log.levels.ERROR)
			return false
		end

		session = new_session
		toggleterm_sessions[container_id] = session
	end

	local ok_open = pcall(function()
		vim.api.nvim_set_current_win(resolve_host_win(target_win))
		session:open()
	end)
	if not ok_open then
		vim.notify("Dockyard: failed to open toggleterm session", vim.log.levels.ERROR)
		return false
	end

	return true
end

function M.open(container_id, shell, target_win)
	if container_id == nil or container_id == "" then
		vim.notify("Dockyard: no container selected", vim.log.levels.WARN)
		return
	end

	if open_with_toggleterm(container_id, shell, target_win) then
		return
	end

	vim.notify("Dockyard: toggleterm not found or failed", vim.log.levels.WARN)
end

return M
