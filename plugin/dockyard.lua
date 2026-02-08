if vim.g.loaded_dockyard then
  return
end
vim.g.loaded_dockyard = true

require("dockyard").setup()
