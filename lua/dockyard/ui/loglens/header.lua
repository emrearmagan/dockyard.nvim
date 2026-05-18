local icons = require("dockyard.ui.icons")

local M = {}

---@param container_name string
---@param opts { follow: boolean, raw: boolean, filter: string|nil, sources?: LogSource[], active_source_idx?: number }|nil
---@return string
function M.render(container_name, opts)
	opts = opts or { follow = true, raw = false, filter = nil }

	local follow_hl = opts.follow and "DockyardTabActive" or "DockyardTabInactive"
	local raw_hl = opts.raw and "DockyardTabActive" or "DockyardTabInactive"
	local filter_active = type(opts.filter) == "string" and opts.filter ~= ""
	local filter_hl = filter_active and "DockyardTabActive" or "DockyardTabInactive"

	local sources = opts.sources or {}
	local active_source_idx = opts.active_source_idx or 0

	local parts = {
		"%#DockyardHeader#  " .. icons.icon("docker") .. "  ",
		container_name or "unknown",
		"  %#Normal#",
	}

	if #sources > 1 then
		local all_hl = active_source_idx == 0 and "DockyardTabActive" or "DockyardTabInactive"
		table.insert(parts, string.format("%%#%s# All (1) %%#Normal#", all_hl))
		for i, src in ipairs(sources) do
			local label = src.name or src.path or ((not src.path) and "docker" or ("src " .. i))
			local hl = active_source_idx == i and "DockyardTabActive" or "DockyardTabInactive"
			table.insert(parts, string.format("%%#%s# %s (%d) %%#Normal#", hl, label, i + 1))
		end
	end

	table.insert(parts, "%=")
	table.insert(parts, "%#DockyardTabInactive# 󰌑 Details %#Normal#")
	table.insert(parts, string.format("%%#%s# r Raw %%#Normal#", raw_hl))
	table.insert(parts, string.format("%%#%s# f Follow %%#Normal#", follow_hl))
	table.insert(parts, string.format("%%#%s# / Filter %%#Normal#", filter_hl))
	table.insert(parts, "%#DockyardTabInactive# q Close %#Normal#")

	if filter_active then
		table.insert(parts, "%#DockyardTabActive# c Clear (" .. tostring(opts.filter) .. ") %#Normal#")
	end

	return table.concat(parts, " ")
end

return M
