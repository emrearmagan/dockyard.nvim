local M = {}

M.get_data = function()
	-- Placeholder for images data
	return {}
end

M.config = {
	has_icons = false,
	columns = {
		{ key = "repository", label = "Repository", min_width = 25, weight = 2, hl = "DockyardName" },
		{ key = "tag", label = "Tag", min_width = 10, weight = 1, hl = "DockyardMuted" },
		{ key = "id", label = "Image ID", min_width = 15, weight = 1, hl = "DockyardMuted" },
		{ key = "created", label = "Created", min_width = 15, weight = 1, hl = "DockyardMuted" },
		{ key = "size", label = "Size", min_width = 10, weight = 1, hl = "DockyardMuted" },
	},
	empty_message = "No images found",
}

return M
