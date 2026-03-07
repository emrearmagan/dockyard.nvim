local M = {}

local palette = {
	running = "#a6e3a1",
	stopped = "#f38ba8",
	paused = "#f9e2af",
	restarting = "#89b4fa",
	dead = "#585b70",
}

---@type table<string, table>
local groups = {
	DockyardRunning = { fg = palette.running, bold = true },
	DockyardStopped = { fg = palette.stopped, bold = true },
	DockyardPaused = { fg = palette.paused, bold = true },
	DockyardRestarting = { fg = palette.restarting, bold = true },
	DockyardDead = { fg = palette.dead, bold = true },

	DockyardTitle = { link = "Title" },
	DockyardHeader = { link = "Label" },
	DockyardNavActive = { link = "TabLineSel" },
	DockyardNavInactive = { link = "TabLine" },
	DockyardBorder = { link = "FloatBorder" },
	DockyardDim = { link = "Comment" },
	DockyardNormal = { link = "Normal" },
}

---Register all Dockyard highlight groups.
function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

---Map Docker status string to highlight group.
---@param status string|nil
---@return string
function M.status_hl(status)
	local s = string.lower(tostring(status or ""))

	if s == "running" then
		return "DockyardRunning"
	elseif s == "paused" then
		return "DockyardPaused"
	elseif s == "restarting" then
		return "DockyardRestarting"
	elseif s == "dead" then
		return "DockyardDead"
	end

	return "DockyardStopped"
end

return M
