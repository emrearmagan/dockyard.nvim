local M = {}

-- Catppuccin Macchiato Palette
M.palette = {
	rosewater = "#f4dbd6",
	flamingo  = "#f0c6c6",
	pink      = "#f5bde6",
	mauve     = "#c6a0f6",
	red       = "#ed8796",
	maroon    = "#ee99a0",
	peach     = "#f5a97f",
	yellow    = "#eed49f",
	green     = "#a6da95",
	teal      = "#8bd5ca",
	sky       = "#91d7e3",
	sapphire  = "#7dc4e4",
	blue      = "#8aadf4",
	lavender  = "#b7bdf8",
	text      = "#cad3f5",
	subtext1  = "#b8c0e0",
	subtext0  = "#a5adcb",
	overlay2  = "#939ab7",
	overlay1  = "#8087a2",
	overlay0  = "#6e738d",
	surface2  = "#5b6078",
	surface1  = "#494d64",
	surface0  = "#363a4f",
	base      = "#24273a",
	mantle    = "#1e2030",
	crust     = "#181926",
}

-- Mapping UI roles to Catppuccin colors
M.groups = {
	header_bg = M.palette.surface0,
	header_fg = M.palette.blue,
	
	name = M.palette.blue,
	image = M.palette.mauve,
	ports = M.palette.peach,
	muted = M.palette.overlay1,
	
	tab_active_bg = M.palette.blue,
	tab_active_fg = M.palette.base,
	tab_inactive_bg = M.palette.surface1,
	tab_inactive_fg = M.palette.subtext0,
	
	action_bg = M.palette.surface0,
	action_fg = M.palette.text,
	
	column_header = M.palette.overlay2,
	
	cursor_line = M.palette.surface1,
	
	status_running = M.palette.green,
	status_stopped = M.palette.red,
}

return M
