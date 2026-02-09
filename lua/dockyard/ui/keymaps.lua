local state = require("dockyard.ui.state")

local M = {}

local MARGIN = 2
local shell_terminals = {}

local function get_shell_terminal(item)
	local id = item.id
	if shell_terminals[id] then
		return shell_terminals[id]
	end

	local has_toggleterm, toggleterm = pcall(require, "toggleterm.terminal")
	if not has_toggleterm then
		return nil
	end

	local Terminal = toggleterm.Terminal
	local term = Terminal:new({
		cmd = "docker exec -it " .. id .. " /bin/sh",
		name = "Docker Shell: " .. item.name,
		hidden = true,
		direction = "horizontal",
		on_open = function(t)
			vim.cmd("startinsert!")
		end,
	})
	shell_terminals[id] = term
	return term
end

function M.setup(table_start, comp)
	local map_opts = { buffer = state.buf, nowait = true, silent = true }

	local function move_to_row(step)
		local curr = vim.api.nvim_win_get_cursor(0)[1]
		local data_start = table_start + 3
		local rows = comp.get_data()
		if #rows == 0 then return end
		local next_l = math.min(math.max(data_start, curr + step), data_start + #rows - 1)
		vim.api.nvim_win_set_cursor(0, { next_l, MARGIN })
	end

	local function get_current_item()
		local curr = vim.api.nvim_win_get_cursor(0)[1]
		local data_start = table_start + 3
		local rows = comp.get_data()
		local idx = curr - data_start + 1
		return rows[idx]
	end

	local function perform_refresh()
		if state.current_view == "containers" then
			require("dockyard.containers").refresh({ silent = true })
		elseif state.current_view == "images" then
			require("dockyard.images").refresh({ silent = true })
		elseif state.current_view == "networks" then
			require("dockyard.networks").refresh({ silent = true })
		end
		require("dockyard.ui").render()
	end

	local function run_action(name, action_fn)
		local item = get_current_item()
		if not item or item._is_spacer then return end
		
		vim.notify("Dockyard: " .. name .. " " .. (item.name or item.repository or item.id) .. "...", vim.log.levels.INFO)
		
		vim.schedule(function()
			local ok = action_fn(item)
			if ok then
				perform_refresh()
			else
				vim.notify("Dockyard: Failed to " .. name, vim.log.levels.ERROR)
			end
		end)
	end

	local function get_items_in_range(start_l, end_l)
		local data_start = table_start + 3
		local rows = comp.get_data()
		local items = {}
		for l = start_l, end_l do
			local idx = l - data_start + 1
			local item = rows[idx]
			if item and not item._is_spacer then
				table.insert(items, item)
			end
		end
		return items
	end

	local function run_bulk_action(name, action_fn)
		local mode = vim.api.nvim_get_mode().mode
		local start_l, end_l
		
		if mode:match("[vV]") then
			start_l = vim.fn.line("v")
			end_l = vim.fn.line(".")
			if start_l > end_l then start_l, end_l = end_l, start_l end
			-- Exit visual mode
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
		else
			start_l = vim.api.nvim_win_get_cursor(0)[1]
			end_l = start_l
		end

		local items = get_items_in_range(start_l, end_l)
		if #items == 0 then return end

		if name then
			vim.notify("Dockyard: " .. name .. " " .. #items .. " items...", vim.log.levels.INFO)
		end
		
		vim.schedule(function()
			local success_count = 0
			for _, item in ipairs(items) do
				local ok = action_fn(item)
				if ok then success_count = success_count + 1 end
			end
			
			if success_count > 0 then
				perform_refresh()
			end
			if success_count < #items and name then
				vim.notify("Dockyard: Failed to " .. name .. " " .. (#items - success_count) .. " items", vim.log.levels.ERROR)
			end
		end)
	end

	-- Navigation & View switching
	vim.keymap.set("n", "j", function() move_to_row(1) end, map_opts)
	vim.keymap.set("n", "k", function() move_to_row(-1) end, map_opts)
	
	-- View Switching
	local function next_view()
		local order = require("dockyard.config").options.display.view_order or { "containers", "images", "networks" }
		local current_idx = 1
		for i, v in ipairs(order) do
			if v == state.current_view then
				current_idx = i
				break
			end
		end
		local next_idx = (current_idx % #order) + 1
		state.current_view = order[next_idx]
		require("dockyard.ui").render()
	end

	local function prev_view()
		local order = require("dockyard.config").options.display.view_order or { "containers", "images", "networks" }
		local current_idx = 1
		for i, v in ipairs(order) do
			if v == state.current_view then
				current_idx = i
				break
			end
		end
		local prev_idx = current_idx - 1
		if prev_idx < 1 then prev_idx = #order end
		state.current_view = order[prev_idx]
		require("dockyard.ui").render()
	end

	-- Global Nav (overridden by specific views if needed)
	vim.keymap.set("n", "<Tab>", next_view, map_opts)
	vim.keymap.set("n", "<S-Tab>", prev_view, map_opts)

	-- Actions
	if state.current_view == "containers" then
		vim.keymap.set({ "n", "v" }, "s", function()
			run_bulk_action(nil, function(item)
				local is_running = item.status and item.status:lower():find("up") == 1
				local action = is_running and "stop" or "start"
				local action_name = is_running and "stopping" or "starting"
				vim.notify("Dockyard: " .. action_name .. " " .. (item.name or item.id) .. "...", vim.log.levels.INFO)
				return require("dockyard.docker").container_action(item.id, action)
			end)
		end, map_opts)

		vim.keymap.set({ "n", "v" }, "x", function()
			run_bulk_action("stopping", function(item)
				return require("dockyard.docker").container_action(item.id, "stop")
			end)
		end, map_opts)

		vim.keymap.set({ "n", "v" }, "r", function()
			run_bulk_action("restarting", function(item)
				return require("dockyard.docker").container_action(item.id, "restart")
			end)
		end, map_opts)

		vim.keymap.set({ "n", "v" }, "d", function()
			local items = {}
			local mode = vim.api.nvim_get_mode().mode
			if mode:match("[vV]") then
				local start_l = vim.fn.line("v")
				local end_l = vim.fn.line(".")
				if start_l > end_l then start_l, end_l = end_l, start_l end
				items = get_items_in_range(start_l, end_l)
			else
				local item = get_current_item()
				if item and not item._is_spacer then table.insert(items, item) end
			end

			if #items == 0 then return end

			local prompt = #items == 1 and ("Remove container " .. (items[1].name or items[1].id) .. "? (y/n): ")
				or ("Remove " .. #items .. " containers? (y/n): ")

			vim.ui.input({ prompt = prompt }, function(input)
				if input and input:lower() == "y" then
					run_bulk_action("removing", function(item)
						return require("dockyard.docker").container_action(item.id, "rm")
					end)
				end
			end)
		end, map_opts)

		-- Logs on L
		vim.keymap.set("n", "L", function()
			local item = get_current_item()
			if not item or item._is_spacer then return end
			require("dockyard.ui.loglens").show_menu(item)
		end, map_opts)

		-- Debugging: Shell
		vim.keymap.set("n", "S", function()
			local item = get_current_item()
			if not item or item._is_spacer then return end
			
			local term = get_shell_terminal(item)
			if term then
				term:toggle()
			else
				require("dockyard.ui.terminal").toggle(item)
			end
		end, map_opts)

		-- Debugging: Inspect (CR or K)
		local function open_inspect()
			local item = get_current_item()
			if not item or item._is_spacer then return end
			require("dockyard.ui.inspect").open(item)
		end
		vim.keymap.set("n", "<CR>", open_inspect, map_opts)
		vim.keymap.set("n", "K", open_inspect, map_opts)
	end

	if state.current_view == "images" then
		vim.keymap.set("n", "d", function()
			local item = get_current_item()
			if not item or not item._is_image then return end
			vim.ui.input({ prompt = "Remove image " .. item.repository .. ":" .. item.tag .. "? (y/n): " }, function(input)
				if input and input:lower() == "y" then
					run_action("Removing image", function(it)
						return require("dockyard.docker").image_action(it.id, "rm")
					end)
				end
			end)
		end, map_opts)

		vim.keymap.set("n", "P", function()
			vim.ui.input({ prompt = "Prune dangling images? (y/n): " }, function(input)
				if input and input:lower() == "y" then
					vim.notify("Dockyard: Pruning images...", vim.log.levels.INFO)
					local ok = require("dockyard.docker").image_prune()
					if ok then perform_refresh() end
				end
			end)
		end, map_opts)

		-- Tree View: Toggle Collapse/Expand (o)
		vim.keymap.set("n", "o", function()
			local item = get_current_item()
			if item and item._is_image then
				require("dockyard.ui.components.images").toggle_collapse(item.id)
				require("dockyard.ui").render()
			end
		end, map_opts)

		-- Debugging: Inspect (CR or K)
		local function open_inspect()
			local item = get_current_item()
			if not item or item._is_spacer then return end
			require("dockyard.ui.inspect").open(item)
		end
		vim.keymap.set("n", "<CR>", open_inspect, map_opts)
		vim.keymap.set("n", "K", open_inspect, map_opts)
	end

	if state.current_view == "networks" then
		vim.keymap.set("n", "d", function()
			local item = get_current_item()
			if not item or not item._is_network then return end
			vim.ui.input({ prompt = "Remove network " .. item.name .. "? (y/n): " }, function(input)
				if input and input:lower() == "y" then
					run_action("Removing network", function(it)
						return require("dockyard.docker").network_action(it.id, "rm")
					end)
				end
			end)
		end, map_opts)

		-- Tree View: Toggle Collapse/Expand (o)
		vim.keymap.set("n", "o", function()
			local item = get_current_item()
			if item and item._is_network then
				require("dockyard.ui.components.networks").toggle_collapse(item.id)
				require("dockyard.ui").render()
			end
		end, map_opts)

		-- Debugging: Inspect (CR or K)
		local function open_inspect()
			local item = get_current_item()
			if not item or item._is_spacer then return end
			require("dockyard.ui.inspect").open(item)
		end
		vim.keymap.set("n", "<CR>", open_inspect, map_opts)
		vim.keymap.set("n", "K", open_inspect, map_opts)
	end

	vim.keymap.set("n", "R", function() 
		perform_refresh()
	end, map_opts)

	vim.keymap.set("n", "q", function() require("dockyard.ui").close() end, map_opts)
	vim.keymap.set("n", "?", function() require("dockyard.ui.help").toggle() end, map_opts)

	-- Initial cursor placement
	local data_start = table_start + 3
	if #comp.get_data() > 0 and vim.api.nvim_win_get_cursor(state.win)[1] < data_start then
		vim.api.nvim_win_set_cursor(state.win, { data_start, MARGIN })
	end
end

return M
