if vim.g.loaded_dockyard then
  return
end
vim.g.loaded_dockyard = true

local ok, dockyard = pcall(require, "dockyard")
if not ok then
  vim.notify("dockyard.nvim: failed to load lua/dockyard/init.lua", vim.log.levels.ERROR)
  return
end

dockyard.setup()
