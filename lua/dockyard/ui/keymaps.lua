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
		
		local id = item.id
		vim.schedule(function()
			local ok = action_fn(id)
			if ok then
				perform_refresh()
			else
				vim.notify("Dockyard: Failed to " .. name, vim.log.levels.ERROR)
			end
		end)
	end

	-- Navigation & View switching
	vim.keymap.set("n", "j", function() move_to_row(1) end, map_opts)
	vim.keymap.set("n", "k", function() move_to_row(-1) end, map_opts)
	
	-- View Switching (Previously Tab/S-Tab)
	local function next_view()
		if state.current_view == "containers" then
			state.current_view = "images"
		elseif state.current_view == "images" then
			state.current_view = "networks"
		else
			state.current_view = "containers"
		end
		require("dockyard.ui").render()
	end

	local function prev_view()
		if state.current_view == "containers" then
			state.current_view = "networks"
		elseif state.current_view == "networks" then
			state.current_view = "images"
		else
			state.current_view = "containers"
		end
		require("dockyard.ui").render()
	end

	vim.keymap.set("n", "L", next_view, map_opts)
	vim.keymap.set("n", "H", prev_view, map_opts)

	-- Actions
	if state.current_view == "containers" then
		vim.keymap.set("n", "s", function()
			local item = get_current_item()
			if not item then return end
			local is_running = (item.status or ""):lower():find("up", 1, true) == 1
			local action = is_running and "stop" or "start"
			run_action(is_running and "Stopping" or "Starting", function(id)
				return require("dockyard.docker").container_action(id, action)
			end)
		end, map_opts)

		vim.keymap.set("n", "r", function()
			run_action("Restarting", function(id)
				return require("dockyard.docker").container_action(id, "restart")
			end)
		end, map_opts)

		vim.keymap.set("n", "d", function()
			local item = get_current_item()
			if not item then return end
			vim.ui.input({ prompt = "Remove container " .. item.name .. "? (y/n): " }, function(input)
				if input and input:lower() == "y" then
					run_action("Removing", function(id)
						return require("dockyard.docker").container_action(id, "rm")
					end)
				end
			end)
		end, map_opts)

		-- Debugging: Logs
		vim.keymap.set("n", "l", function()
			local item = get_current_item()
			if not item or item._is_spacer then return end
			vim.cmd("belowright split")
			local log_win = vim.api.nvim_get_current_win()
			local log_buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_win_set_buf(log_win, log_buf)
			vim.api.nvim_buf_set_name(log_buf, "docker-logs-" .. item.name)
			vim.api.nvim_buf_set_option(log_buf, "buftype", "nofile")
			
			vim.fn.termopen("docker logs -f --tail 100 " .. item.id)
			vim.cmd("normal! G")
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
		vim.keymap.set("n", "i", open_inspect, map_opts)
	end

	if state.current_view == "images" then
		vim.keymap.set("n", "d", function()
			local item = get_current_item()
			if not item or not item._is_image then return end
			vim.ui.input({ prompt = "Remove image " .. item.repository .. ":" .. item.tag .. "? (y/n): " }, function(input)
				if input and input:lower() == "y" then
					run_action("Removing image", function(id)
						return require("dockyard.docker").image_action(id, "rm")
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

		-- Tree View: Toggle Collapse/Expand (Tab)
		vim.keymap.set("n", "<Tab>", function()
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
		vim.keymap.set("n", "i", open_inspect, map_opts)
	end

	if state.current_view == "networks" then
		vim.keymap.set("n", "d", function()
			local item = get_current_item()
			if not item or not item._is_network then return end
			vim.ui.input({ prompt = "Remove network " .. item.name .. "? (y/n): " }, function(input)
				if input and input:lower() == "y" then
					run_action("Removing network", function(id)
						return require("dockyard.docker").network_action(id, "rm")
					end)
				end
			end)
		end, map_opts)

		-- Tree View: Toggle Collapse/Expand (Tab)
		vim.keymap.set("n", "<Tab>", function()
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
		vim.keymap.set("n", "i", open_inspect, map_opts)
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
