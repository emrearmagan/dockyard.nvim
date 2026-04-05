local M = {}
local state = require("dockyard.ui.state")
local keymaps = require("dockyard.ui.keymaps")
local ui_utils = require("dockyard.ui.utils")
local config = require("dockyard.config")
local view_modules = {
	containers = require("dockyard.ui.views.containers.init"),
	images = require("dockyard.ui.views.images.init"),
	networks = require("dockyard.ui.views.networks.init"),
}

local win_config_by_mode = ui_utils.win_config_by_mode

local function create_footer_buf()
	if state.footer_buf_id ~= nil and vim.api.nvim_buf_is_valid(state.footer_buf_id) then
		return state.footer_buf_id
	end

	local buf = ui_utils.create_footer_buf("DockyardFooter")

	state.footer_buf_id = buf
	return buf
end

local function close_footer()
	if state.footer_win_id ~= nil and vim.api.nvim_win_is_valid(state.footer_win_id) then
		vim.api.nvim_win_close(state.footer_win_id, true)
	end
	state.footer_win_id = nil

	if state.footer_buf_id ~= nil and vim.api.nvim_buf_is_valid(state.footer_buf_id) then
		pcall(vim.api.nvim_buf_delete, state.footer_buf_id, { force = true })
	end
	state.footer_buf_id = nil
end

local function ensure_footer()
	if state.mode ~= "full" or state.win_id == nil or not vim.api.nvim_win_is_valid(state.win_id) then
		close_footer()
		return
	end

	local buf = create_footer_buf()
	if state.footer_win_id ~= nil and vim.api.nvim_win_is_valid(state.footer_win_id) then
		vim.api.nvim_win_set_buf(state.footer_win_id, buf)
	else
		local prev = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(state.win_id)
		vim.cmd("botright split")
		state.footer_win_id = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(state.footer_win_id, buf)
		ui_utils.apply_footer_win_config(state.footer_win_id)
		vim.api.nvim_set_option_value("winblend", 0, { win = state.footer_win_id })
		vim.api.nvim_set_option_value("winfixbuf", true, { win = state.footer_win_id })
		if prev ~= nil and vim.api.nvim_win_is_valid(prev) then
			vim.api.nvim_set_current_win(prev)
		end
	end

	pcall(vim.api.nvim_win_set_height, state.footer_win_id, 1)
	pcall(function()
		vim.api.nvim_win_call(state.footer_win_id, function()
			vim.cmd("wincmd J")
		end)
	end)
end

---@param on_done fun()|nil
---@param opts { force_update?: boolean }|nil
local function update_active_view(on_done, opts)
	local module = view_modules[state.current_view]
	if module and type(module.update) == "function" then
		module.update(on_done, opts)
	elseif on_done then
		on_done()
	end
end

local function teardown_active_view()
	if state.buf_id == nil then
		return
	end
	local module = view_modules[state.current_view]
	if module and type(module.teardown) == "function" then
		module.teardown(state.buf_id)
	end
end

local function setup_active_view()
	if state.buf_id == nil then
		return
	end
	local module = view_modules[state.current_view]
	if module and type(module.setup) == "function" then
		module.setup(state.buf_id, vim.notify)
	end
end

local function open_with(mode, win_config_fn)
	state.prev_win = vim.api.nvim_get_current_win()
	state.mode = mode

	if state.buf_id == nil or not vim.api.nvim_buf_is_valid(state.buf_id) then
		state.buf_id = ui_utils.create_buf()
	end

	if mode == "full" then
		vim.cmd("tabnew")
		state.tab_id = vim.api.nvim_get_current_tabpage()
		state.win_id = vim.api.nvim_get_current_win()
		local tab_buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_win_set_buf(state.win_id, state.buf_id)
		if tab_buf ~= state.buf_id and vim.api.nvim_buf_is_valid(tab_buf) then
			pcall(vim.api.nvim_buf_delete, tab_buf, { force = true })
		end
	else
		state.win_id = vim.api.nvim_open_win(state.buf_id, true, win_config_fn())
		state.tab_id = nil
	end
	ensure_footer()
	ui_utils.apply_win_config(state.win_id, mode)
	keymaps.register_global(state.buf_id, {
		close = M.close,
		refresh = M.refresh,
		next_view = M.next_view,
		prev_view = M.prev_view,
		open_help = function()
			require("dockyard.ui.popups.help").open()
		end,
	})

	return state.win_id
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
	teardown_active_view()
	state.current_view = views[next_idx]
	setup_active_view()
	update_active_view(nil)
end

M.resize = function()
	if not M.is_open() then
		return
	end

	if state.mode == "full" then
		ensure_footer()
		update_active_view(nil)
		return
	end

	local config_fn = win_config_by_mode[state.mode] or ui_utils.panel_win_config
	vim.api.nvim_win_set_config(state.win_id, config_fn())
	update_active_view(nil)
end

M.is_open = function()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

M.open = function()
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		update_active_view(nil)
		return state.win_id
	end

	local win_id = open_with("panel", ui_utils.panel_win_config)
	setup_active_view()
	update_active_view(nil, { force_update = true })
	return win_id
end

M.open_full = function()
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win_id)
		update_active_view(nil)
		return state.win_id
	end

	local win_id = open_with("full", ui_utils.full_win_config)
	setup_active_view()
	update_active_view(nil, { force_update = true })
	return win_id
end

M.close = function()
	if not M.is_open() then
		return
	end

	if state.mode == "full" then
		close_footer()
		if state.tab_id ~= nil and vim.api.nvim_tabpage_is_valid(state.tab_id) then
			local current_tab = vim.api.nvim_get_current_tabpage()
			if current_tab ~= state.tab_id then
				vim.api.nvim_set_current_tabpage(state.tab_id)
			end
			vim.cmd("tabclose")
		end
	else
		vim.api.nvim_win_close(state.win_id, true)
	end
	state.win_id = nil
	close_footer()

	if state.prev_win ~= nil and vim.api.nvim_win_is_valid(state.prev_win) then
		vim.api.nvim_set_current_win(state.prev_win)
	end

	state.prev_win = nil
	state.tab_id = nil
	teardown_active_view()
	if state.buf_id ~= nil then
		keymaps.unregister_global(state.buf_id)
	end
end

M.refresh = function()
	if not M.is_open() then
		return
	end

	update_active_view(nil, { force_update = true })
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
