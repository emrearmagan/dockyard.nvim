local M = {}

---@param container_name string
---@param opts { follow: boolean, raw: boolean }|nil
---@return string
function M.render(container_name, opts)
	opts = opts or { follow = true, raw = false }

	local follow_hl = opts.follow and "DockyardTabActive" or "DockyardTabInactive"
	local raw_hl = opts.raw and "DockyardTabActive" or "DockyardTabInactive"

	local parts = {
		"%#DockyardHeader#    ",
		container_name or "unknown",
		"  %#Normal#",
		"%=",
		"%#DockyardTabInactive# 󰌑 Details %#Normal#",
		string.format("%%#%s# r Raw %%#Normal#", raw_hl),
		string.format("%%#%s# f Follow %%#Normal#", follow_hl),
		"%#DockyardTabInactive# / Filter %#Normal#",
		"%#DockyardTabInactive# q Close %#Normal#",
	}

	return table.concat(parts, " ")
end

return M
