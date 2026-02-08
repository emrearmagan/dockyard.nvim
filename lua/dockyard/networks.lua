local docker = require("dockyard.docker")

local M = {}

local state = {
  networks = {},
  last_error = nil,
  last_updated = nil,
}

local function now()
  local uv = vim.uv or vim.loop
  return (uv and uv.now) and uv.now() or os.time()
end

function M.refresh(opts)
  opts = opts or {}
  local networks, err = docker.list_networks(opts.docker)

  if err then
    state.networks = {}
    state.last_error = err
    state.last_updated = now()
    return nil, err
  end

  state.networks = networks or {}
  state.last_error = nil
  state.last_updated = now()

  return state.networks
end

function M.all()
  local copy = {}
  for i, v in ipairs(state.networks) do copy[i] = v end
  return copy
end

return M
