local docker = require("dockyard.docker")

local M = {}

local function create_state(fetch_fn)
	local state = {
		items = {},
		last_error = nil,
		last_updated = nil,
	}

	local S = {}

	function S.refresh(opts)
		fetch_fn(opts, function(result)
			if not result.ok then
				state.items = {}
				state.last_error = result.error
				state.last_updated = os.time()

				if not opts.silent then
					vim.notify(string.format("Dockyard: %s", result.error), vim.log.levels.ERROR)
				end

				if opts.on_error then
					opts.on_error(result.error)
				end

				state.items = result.data or {}
				state.last_error = nil
				state.last_updated = os.time()
				if opts.on_success then
					opts.on_success(result.data)
				end
			end
		end)
	end

	function S.get_by_id(id)
		for _, item in ipairs(state.items) do
			if item.id == id then
				return item
			end
		end
		return nil
	end

	function S.last_error()
		return state.last_error
	end

	S.last_updated = function()
		return state.last_updated
	end

	return S
end

M.containers = create_state(docker.list_containers)
M.images = create_state(docker.list_images)
M.networks = create_state(docker.list_networks)

return M
