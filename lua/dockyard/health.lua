local M = {}

function M.check()
	vim.health.start("Requirements")

	if vim.fn.has("nvim-0.7") == 0 then
		vim.health.error("Neovim >= 0.7 required")
	else
		vim.health.ok("Neovim version compatible")
	end

	local ok, _ = pcall(require, "plenary.job")
	if ok then
		vim.health.ok("plenary.nvim found")
	else
		vim.health.error("plenary.nvim required but not found")
	end

	vim.health.start("Docker")

	if vim.fn.executable("docker") == 1 then
		vim.health.ok("Docker CLI found")

		local version = vim.fn.system("docker --version 2>/dev/null"):gsub("\n", "")
		if vim.v.shell_error == 0 then
			vim.health.ok(version)
		end

		local result = vim.fn.system("docker info 2>/dev/null")
		if vim.v.shell_error == 0 then
			vim.health.ok("Docker daemon running")
		else
			vim.health.error("Docker daemon not running")
		end
	else
		vim.health.error("Docker CLI not found")
	end

	vim.health.start("Plugin")

	if vim.g.loaded_dockyard then
		vim.health.ok("Plugin loaded")
	else
		vim.health.info("Plugin not loaded yet")
	end
end

return M
