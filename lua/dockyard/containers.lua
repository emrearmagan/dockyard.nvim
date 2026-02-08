local docker = require("dockyard.docker")

local M = {}

local state = {
  containers = {},
  last_error = nil,
  last_updated = nil,
}

local notifier = vim.notify

local function now()
  local uv = vim.uv or vim.loop
  if uv and uv.now then
    return uv.now()
  end
  return os.time()
end

local function shallow_copy(list)
  local copy = {}
  for idx, value in ipairs(list) do
    copy[idx] = value
  end
  return copy
end

local function filter(list, predicate)
  local results = {}
  for _, entry in ipairs(list) do
    if predicate(entry) then
      results[#results + 1] = entry
    end
  end
  return results
end

local function notify(level, message)
  if type(notifier) ~= "function" then
    return
  end
  local ok = pcall(notifier, message, level)
  if not ok and notifier ~= vim.notify then
    pcall(vim.notify, message, level)
  end
end

function M.set_notifier(fn)
  if fn == nil then
    notifier = vim.notify
    return
  end
  notifier = fn
end

function M.refresh(opts)
  opts = opts or {}
  local containers, err = docker.list_containers(opts.docker)

  if err then
    state.containers = {}
    state.last_error = err
    state.last_updated = now()
    if not opts.silent then
      notify(vim.log.levels.ERROR, string.format("dockyard: %s", err))
    end
    if type(opts.on_error) == "function" then
      opts.on_error(err)
    end
    return nil, err
  end

  state.containers = containers or {}
  state.last_error = nil
  state.last_updated = now()

  if type(opts.on_success) == "function" then
    opts.on_success(state.containers)
  end

  return state.containers
end

function M.all()
  return shallow_copy(state.containers)
end

local function has_status_prefix(entry, prefix)
  if not entry.status or not prefix then
    return false
  end
  return entry.status:lower():find(prefix:lower(), 1, true) == 1
end

function M.running()
  return filter(state.containers, function(entry)
    return has_status_prefix(entry, "up")
  end)
end

function M.exited()
  return filter(state.containers, function(entry)
    return has_status_prefix(entry, "exited")
  end)
end

function M.filter(predicate)
  if type(predicate) ~= "function" then
    return {}
  end
  return filter(state.containers, predicate)
end

function M.last_error()
  return state.last_error
end

function M.last_updated()
  return state.last_updated
end

return M
