local M = {}

local docker = require("dockyard.docker")

function M.remove(node, on_done, notify)
	if not node or node.kind ~= "image" or not node.item then
		return
	end

	vim.ui.input({ prompt = "Remove image " .. tostring(node.item.repository or node.item.id) .. "? (y/n)" }, function(input)
		if input ~= "y" and input ~= "Y" then
			return
		end

		docker.image_action(node.item.id, "rm", function(res)
			if not res.ok then
				(notify or vim.notify)("Image remove failed: " .. tostring(res.error), vim.log.levels.ERROR)
				on_done()
				return
			end

			on_done()
		end)
	end)
end

function M.prune(on_done, notify)
	docker.image_prune(function(res)
		if not res.ok then
			(notify or vim.notify)("Image prune failed: " .. tostring(res.error), vim.log.levels.ERROR)
			on_done()
			return
		end

		(notify or vim.notify)("Pruned dangling images", vim.log.levels.INFO)
		on_done()
	end)
end

return M
