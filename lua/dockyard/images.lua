local docker = require("dockyard.docker")

local M = {}

local state = {
  images = {},
  last_error = nil,
  last_updated = nil,
}

local function now()
  local uv = vim.uv or vim.loop
  return (uv and uv.now) and uv.now() or os.time()
end

function M.refresh(opts)
  opts = opts or {}
  local images, err = docker.list_images(opts.docker)

  if err then
    state.images = {}
    state.last_error = err
    state.last_updated = now()
    return nil, err
  end

  state.images = images or {}
  state.last_error = nil
  state.last_updated = now()

  return state.images
end

function M.all()
  local copy = {}
  for i, v in ipairs(state.images) do copy[i] = v end
  return copy
end

return M
