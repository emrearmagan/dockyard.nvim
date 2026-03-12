local M = {}

---@param container_name string
---@param opts { follow: boolean, raw: boolean, filter: string|nil }|nil
---@return string
function M.render(container_name, opts)
	opts = opts or { follow = true, raw = false, filter = nil }

	local follow_hl = opts.follow and "DockyardTabActive" or "DockyardTabInactive"
	local raw_hl = opts.raw and "DockyardTabActive" or "DockyardTabInactive"
	local filter_active = type(opts.filter) == "string" and opts.filter ~= ""
	local filter_hl = filter_active and "DockyardTabActive" or "DockyardTabInactive"

	local parts = {
		"%#DockyardHeader#    ",
		container_name or "unknown",
		"  %#Normal#",
		"%=",
		"%#DockyardTabInactive# 󰌑 Details %#Normal#",
		string.format("%%#%s# r Raw %%#Normal#", raw_hl),
		string.format("%%#%s# f Follow %%#Normal#", follow_hl),
		string.format("%%#%s# / Filter %%#Normal#", filter_hl),
		"%#DockyardTabInactive# q Close %#Normal#",
	}

	if filter_active then
		table.insert(parts, "%#DockyardTabActive# c Clear (" .. tostring(opts.filter) .. ") %#Normal#")
	end

	return table.concat(parts, " ")
end

return M
