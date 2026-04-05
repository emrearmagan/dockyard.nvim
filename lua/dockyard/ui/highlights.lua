local M = {}

local palette = {
	bg_soft = "#363a4f",
	fg = "#cad3f5",
	muted = "#8087a2",

	blue = "#8aadf4",
	green = "#a6da95",
	yellow = "#eed49f",
	red = "#ed8796",
	orange = "#f5a97f",
	mauve = "#c6a0f6",

	tab_inactive_bg = "#494d64",
	tab_inactive_fg = "#a5adcb",
	column_header = "#939ab7",
}

---@type table<string, table>
local groups = {
	DockyardRunning = { fg = palette.green, bold = true },
	DockyardStopped = { fg = palette.red, bold = true },
	DockyardPaused = { fg = palette.yellow, bold = true },
	DockyardRestarting = { fg = palette.blue, bold = true },
	DockyardDead = { fg = palette.muted, bold = true },
	DockyardPending = { fg = palette.orange, bold = true },

	DockyardHeader = { bg = palette.bg_soft, fg = palette.blue, bold = true },
	DockyardTitle = { fg = palette.blue, bold = true },
	DockyardTabActive = { bg = palette.blue, fg = "#1e1e2e", bold = true },
	DockyardTabInactive = { bg = palette.tab_inactive_bg, fg = palette.tab_inactive_fg },
	DockyardAction = { fg = palette.fg },
	DockyardActionRefresh = { bg = palette.green, fg = "#1e1e2e", bold = true },
	DockyardHelpKey = { fg = palette.orange, bold = true },
	DockyardColumnHeader = { fg = palette.column_header, bold = true },
	DockyardName = { fg = palette.blue },
	DockyardImage = { fg = palette.mauve },
	DockyardPorts = { fg = palette.orange },
	DockyardMuted = { fg = palette.muted },

	DockyardNavActive = { link = "DockyardTabActive" },
	DockyardNavInactive = { link = "DockyardTabInactive" },
	DockyardFooterBackground = { bg = palette.bg_soft, fg = palette.fg },
	DockyardBorder = { link = "FloatBorder" },
	DockyardDim = { fg = palette.muted },
	DockyardNormal = { link = "Normal" },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

---@param status ContainerStatus|nil
---@return string
function M.status_hl(status)
	if status == "restarting" or status == "starting" or status == "removing" then
		return "DockyardPending"
	elseif status == "running" then
		return "DockyardRunning"
	elseif status == "paused" then
		return "DockyardPaused"
	elseif status == "restarting" then
		return "DockyardRestarting"
	elseif status == "dead" then
		return "DockyardDead"
	end

	return "DockyardStopped"
end

return M
