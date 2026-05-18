local M = {}

function M.check()
	--- Requirements
	vim.health.start("Requirements")
	if vim.fn.has("nvim-0.10") == 0 then
		vim.health.error("Neovim >= 0.10 required")
	else
		vim.health.ok("Neovim version compatible")
	end

	if type(vim.system) == "function" then
		vim.health.ok("vim.system available")
	else
		vim.health.error("vim.system unavailable; Neovim >= 0.10 required")
	end

	local has_toggleterm, _ = pcall(require, "toggleterm.terminal")
	if has_toggleterm then
		vim.health.ok("toggleterm.nvim found")
	else
		vim.health.warn("toggleterm.nvim not found")
	end

	--- Docker
	vim.health.start("Docker")
	if vim.fn.executable("docker") == 1 then
		vim.health.ok("Docker CLI found")

		local version = vim.fn.system("docker --version 2>/dev/null"):gsub("\n", "")
		if vim.v.shell_error == 0 then
			vim.health.ok(version)
		end

		vim.fn.system("docker info 2>/dev/null")
		if vim.v.shell_error == 0 then
			vim.health.ok("Docker daemon running")
		else
			vim.health.error("Docker daemon not running")
		end
	else
		vim.health.error("Docker CLI not found")
	end

	--- Plugin
	vim.health.start("Plugin")
	if vim.g.loaded_dockyard then
		vim.health.ok("Plugin loaded")
	else
		vim.health.info("Plugin not loaded yet")
	end

	if vim.fn.exists(":Dockyard") > 0 then
		vim.health.ok(":Dockyard command registered")
	else
		vim.health.error(":Dockyard command not found; call require('dockyard').setup()")
	end

	if vim.fn.exists(":DockyardFloat") > 0 then
		vim.health.ok(":DockyardFloat command registered")
	else
		vim.health.error(":DockyardFloat command not found; call require('dockyard').setup()")
	end

	--- Keymaps
	vim.health.start("Keymaps")
	local by_context = require("dockyard.core.keymaps").validate()
	local context_names = vim.tbl_keys(by_context)
	table.sort(context_names)

	local has_conflicts = false
	for _, ctx in ipairs(context_names) do
		local conflicts = by_context[ctx] or {}
		local keys = vim.tbl_keys(conflicts)
		table.sort(keys)
		if #keys == 0 then
			vim.health.ok(string.format("%s: no conflicting mapped keys", ctx))
		else
			has_conflicts = true
			vim.health.warn(string.format("%s: %d conflicting key(s)", ctx, #keys))
			for _, key in ipairs(keys) do
				vim.health.warn(string.format("  %s -> %s", key, table.concat(conflicts[key], ", ")))
			end
		end
	end
	if not has_conflicts and #context_names == 0 then
		vim.health.ok("No conflicting mapped keys")
	end
end

return M
