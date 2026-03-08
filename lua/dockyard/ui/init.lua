local M = {}
local state = require("dockyard.ui.state")
local data_state = require("dockyard.state")
local renderer = require("dockyard.ui.renderer")
local keymaps = require("dockyard.ui.keymaps")
local ui_utils = require("dockyard.ui.utils")
local config = require("dockyard.config")

local win_config_by_mode = ui_utils.win_config_by_mode

local function unregister_view_keymaps()
	if state.buf_id == nil then
		return
	end
	keymaps.unregister_view(state.buf_id, state.current_view)
end

local function register_view_keymaps()
	if state.buf_id == nil then
		return
	end
	keymaps.register_view(state.buf_id, state.current_view)
end

local function open_with(mode, win_config_fn)
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		renderer.render()
		return state.win_id
	end

	state.prev_win = vim.api.nvim_get_current_win()
	state.mode = mode

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = ui_utils.create_buf()
	end

	state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_config_fn())
	ui_utils.apply_win_config(state.win_id, mode)
	renderer.render()
	keymaps.register_global(state.buf_id, {
		close = M.close,
		refresh = M.refresh,
		next_view = M.next_view,
		prev_view = M.prev_view,
		open_help = function()
			vim.cmd("help dockyard")
		end,
	})
	register_view_keymaps()

	data_state.containers.refresh({
		silent = true,
		on_success = function()
			if M.is_open() then
				renderer.render()
			end
		end,
		on_error = function()
			if M.is_open() then
				renderer.render()
			end
		end,
	})

	return state.win_id
end

local function refresh_current_view_data(on_done)
	local refreshers = {
		containers = data_state.containers,
		images = data_state.images,
		networks = data_state.networks,
	}

	local target = refreshers[state.current_view]
	if target == nil then
		on_done()
		return
	end

	target.refresh({
		silent = true,
		on_success = on_done,
		on_error = on_done,
	})
end

local function cycle_view(step)
	local views = config.options.display.views or { "containers", "images", "networks" }
	if #views == 0 then
		return
	end

	local idx = 1
	for i, view in ipairs(views) do
		if view == state.current_view then
			idx = i
			break
		end
	end

	local next_idx = ((idx - 1 + step) % #views) + 1
	unregister_view_keymaps()
	state.current_view = views[next_idx]
	register_view_keymaps()
	M.refresh()
end

M.resize = function()
	if not M.is_open() then
		return
	end

	local config_fn = win_config_by_mode[state.mode] or ui_utils.panel_win_config
	vim.api.nvim_win_set_config(state.win_id, config_fn())
	renderer.render()
end

M.is_open = function()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

M.open = function()
	return open_with("panel", ui_utils.panel_win_config)
end

M.open_full = function()
	return open_with("full", ui_utils.full_win_config)
end

M.close = function()
	if not M.is_open() then
		return
	end

	vim.api.nvim_win_close(state.win_id, true)
	state.win_id = nil

	if state.prev_win ~= nil and vim.api.nvim_win_is_valid(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end

	state.prev_win = nil
	unregister_view_keymaps()
	if state.buf_id ~= nil then
		keymaps.unregister_global(state.buf_id)
	end
end

M.refresh = function()
	if not M.is_open() then
		return
	end

	refresh_current_view_data(function()
		if M.is_open() then
			renderer.render()
		end
	end)
end

M.next_view = function()
	cycle_view(1)
end

M.prev_view = function()
	cycle_view(-1)
end

local resize_group = vim.api.nvim_create_augroup("DockyardUIResize", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
	group = resize_group,
	callback = function()
		M.resize()
	end,
})

return M
