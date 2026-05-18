local M = {}

M.core = require("dockyard.files.core")
M.browser = require("dockyard.files.browser")

---@param container string
---@param path string|nil  defaults to "/"
function M.open(container, path)
	return M.browser.open(container, path or "/")
end

return M
