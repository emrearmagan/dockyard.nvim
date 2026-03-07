local M = {}

local palette = {
	bg_soft = "#2b2f3a",
	fg = "#d9e0ee",
	muted = "#7f849c",

	blue = "#89b4fa",
	green = "#a6e3a1",
	yellow = "#f9e2af",
	red = "#f38ba8",
	orange = "#fab387",

	tab_inactive_bg = "#3a3f4b",
	tab_inactive_fg = "#aab1c3",
}

---@type table<string, table>
local groups = {
	DockyardRunning = { fg = palette.green, bold = true },
	DockyardStopped = { fg = palette.red, bold = true },
	DockyardPaused = { fg = palette.yellow, bold = true },
	DockyardRestarting = { fg = palette.blue, bold = true },
	DockyardDead = { fg = palette.muted, bold = true },

	DockyardHeader = { bg = palette.bg_soft, fg = palette.blue, bold = true },
	DockyardTitle = { fg = palette.blue, bold = true },
	DockyardTabActive = { bg = palette.blue, fg = "#1e1e2e", bold = true },
	DockyardTabInactive = { bg = palette.tab_inactive_bg, fg = palette.tab_inactive_fg },
	DockyardAction = { fg = palette.fg },
	DockyardActionRefresh = { bg = palette.green, fg = "#1e1e2e", bold = true },
	DockyardActionHelp = { bg = palette.orange, fg = "#1e1e2e", bold = true },

	-- compatibility aliases (older names used in newer docs)
	DockyardNavActive = { link = "DockyardTabActive" },
	DockyardNavInactive = { link = "DockyardTabInactive" },
	DockyardBorder = { link = "FloatBorder" },
	DockyardDim = { fg = palette.muted },
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
