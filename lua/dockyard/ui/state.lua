--- @class UIState
--- @field win_id number|nil ID of the Dockyard window, or nil if not open
--- @field buf_id number|nil ID of the Dockyard buffer, or nil if not
--- @field prev_win number|nil ID of the previously focused window before opening Dockyard, or nil if not set
--- @field tab_id number|nil ID of Dockyard tab in full mode
--- @field footer_win_id number|nil ID of Dockyard footer window in full mode
--- @field footer_buf_id number|nil ID of Dockyard footer buffer in full mode
--- @field current_view "containers"|"images"|"networks" The currently active view
--- @field line_map table A mapping of buffer line numbers to item IDs for the currents view
--- @field mode "panel"|"full" The current display mode of the UI

--- @type UIState
local state = {
	win_id = nil,
	buf_id = nil,
	prev_win = nil,
	tab_id = nil,
	footer_win_id = nil,
	footer_buf_id = nil,
	current_view = "containers",
	line_map = {},
	mode = "panel",
}

return state
