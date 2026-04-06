local docker = require("dockyard.core.docker")

local M = {}

local function create_state(fetch_fn)
	local state = {
		items = {},
		last_error = nil,
		last_updated = nil,
	}

	local S = {}

	---@param opts? { silent?: boolean, on_success?: fun(items: table[]), on_error?: fun(err: string) }
	function S.refresh(opts)
		opts = opts or {}

		fetch_fn(function(result)
			if result.ok then
				state.items = result.data or {}
				state.last_error = nil
				state.last_updated = os.time()
				if opts.on_success then
					opts.on_success(state.items)
				end
				return
			end

			state.items = {}
			state.last_error = result.error
			state.last_updated = os.time()

			if not opts.silent then
				vim.notify(string.format("Dockyard: %s", tostring(result.error)), vim.log.levels.ERROR)
			end

			if opts.on_error then
				opts.on_error(tostring(result.error))
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

	function S.get_items()
		return state.items
	end

	return S
end

M.containers = create_state(docker.list_containers)
M.images = create_state(docker.list_images)
M.networks = create_state(docker.list_networks)
M.volumes = create_state(docker.list_volumes)

return M
