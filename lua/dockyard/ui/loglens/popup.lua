local popup_factory = require("dockyard.ui.popups.popup")

local M = {}

local popup = nil
local current = {
	entry = nil,
}

local function split_lines(value)
	local lines = vim.split(tostring(value or ""), "\n", { plain = true, trimempty = false })
	if #lines == 0 then
		return { "" }
	end
	return lines
end

local function render_content()
	local pretty = vim.inspect(current.entry.formatted, { newline = "\n", indent = "  " })
	return {
		title = " LogLens Entry ",
		footer = " q/Esc Close ",
		lines = split_lines(pretty),
		spans = {},
	}
end

local function ensure_popup()
	if popup then
		return
	end

	popup = popup_factory.create({
		title = " LogLens ",
		view = "entry",
		on_resize = function()
			if current.entry ~= nil then
				M.render_current()
			end
		end,
		on_close = function()
			current.entry = nil
		end,
	})
end

function M.render_current()
	if not popup or current.entry == nil then
		return
	end

	local content = render_content()
	popup.open({
		title = content.title,
		footer = content.footer,
		view = "entry",
	})

	popup.set_content(content.lines, content.spans)
end

---@param entry LogLensEntry
function M.open(entry)
	ensure_popup()
	if entry == nil then
		return
	end

	current.entry = entry
	M.render_current()
end

function M.is_open()
	return popup ~= nil and popup.is_open()
end

function M.close()
	if popup then
		popup.close()
	end
end

return M
