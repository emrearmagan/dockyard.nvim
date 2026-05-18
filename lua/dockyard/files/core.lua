local docker = require("dockyard.core.docker")

local M = {}

---@class DockyardFileEntry
---@field name string
---@field type "file"|"directory"|"link"
---@field kind string  Raw single-char type: f|d|l|o (other = device/socket/fifo)
---@field size integer
---@field mtime string|nil
---@field target string|nil  -- for symlinks

local function split_lines(s)
	if not s or s == "" then
		return {}
	end
	local lines = {}
	for line in (s .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	if #lines > 0 and lines[#lines] == "" then
		table.remove(lines)
	end
	return lines
end

---@param container string
---@param argv string[]
---@param cb fun(res: { ok: boolean, stdout: string[], error?: string })
local function exec(container, argv, cb)
	local args = { "exec", container }
	vim.list_extend(args, argv)
	docker.run(args, function(res)
		cb({
			ok = res.ok,
			stdout = res.ok and split_lines(res.data) or {},
			error = res.error,
		})
	end)
end

-- kind: f (file) | d (dir) | l (link) | o (other: char/block/socket/fifo)
local LIST_SCRIPT = [[
cd "$1" 2>/dev/null || exit 0
for f in .[!.]* ..?* *; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  case "$f" in .|..) continue ;; esac
  if [ -L "$f" ]; then
    kind=l; target=$(readlink -- "$f" 2>/dev/null)
  elif [ -d "$f" ]; then
    kind=d; target=
  elif [ -f "$f" ]; then
    kind=f; target=
  else
    kind=o; target=
  fi
  size=$(stat -c %s -- "$f" 2>/dev/null) || size=0
  mtime=$(stat -c %y -- "$f" 2>/dev/null); mtime=${mtime%%.*}
  printf '%s|%s|%s|%s|%s\n' "$kind" "$size" "$mtime" "$target" "$f"
done
]]

---@param container string
---@param path string
---@param cb fun(res: { ok: boolean, entries?: DockyardFileEntry[], error?: string })
function M.list(container, path, cb)
	docker.run({ "exec", container, "sh", "-c", LIST_SCRIPT, "sh", path }, function(res)
		if not res.ok then
			return cb({ ok = false, error = res.error })
		end
		local entries = {}
		for line in (res.data or ""):gmatch("[^\n]+") do
			local kind, size, mtime, target, name = line:match("^([fdlo])|([^|]*)|([^|]*)|([^|]*)|(.+)$")
			if kind and name then
				table.insert(entries, {
					name = name,
					kind = kind,
					type = kind == "d" and "directory" or kind == "l" and "link" or "file",
					size = tonumber(size) or 0,
					mtime = mtime ~= "" and mtime or nil,
					target = target ~= "" and target or nil,
				})
			end
		end
		table.sort(entries, function(a, b)
			if a.type ~= b.type then
				return a.type == "directory"
			end
			return a.name:lower() < b.name:lower()
		end)
		cb({ ok = true, entries = entries })
	end)
end

---@param cb fun(res: { ok: boolean, lines?: string[], error?: string })
function M.read(container, path, cb)
	exec(container, { "cat", "--", path }, function(res)
		if not res.ok then
			return cb({ ok = false, error = res.error })
		end
		cb({ ok = true, lines = res.stdout })
	end)
end

---@param cb fun(res: { ok: boolean, error?: string })
function M.write(container, path, lines, cb)
	local tmp = vim.fn.tempname()
	local fh, ferr = io.open(tmp, "wb")
	if not fh then
		return cb({ ok = false, error = ferr or "could not open tempfile" })
	end
	fh:write(table.concat(lines, "\n"))
	if #lines > 0 then
		fh:write("\n")
	end
	fh:close()

	docker.run({ "cp", tmp, container .. ":" .. path }, function(res)
		os.remove(tmp)
		if res.ok then
			cb({ ok = true })
		else
			cb({ ok = false, error = res.error or "docker cp failed" })
		end
	end)
end

function M.mkdir(container, path, cb)
	exec(container, { "mkdir", "-p", "--", path }, function(res)
		cb({ ok = res.ok, error = (not res.ok) and res.error or nil })
	end)
end

function M.rm(container, path, cb)
	exec(container, { "rm", "-rf", "--", path }, function(res)
		cb({ ok = res.ok, error = (not res.ok) and res.error or nil })
	end)
end

function M.mv(container, src, dst, cb)
	exec(container, { "mv", "--", src, dst }, function(res)
		cb({ ok = res.ok, error = (not res.ok) and res.error or nil })
	end)
end

---@param cb fun(res: { ok: boolean, paths?: string[], error?: string })
function M.find(container, path, pattern, cb)
	exec(container, { "find", path, "-name", pattern }, function(res)
		if not res.ok then
			return cb({ ok = false, error = res.error })
		end
		cb({ ok = true, paths = res.stdout })
	end)
end

---@param path string
function M.normalize(path)
	if path == nil or path == "" then
		return "/"
	end
	if path:sub(1, 1) ~= "/" then
		path = "/" .. path
	end
	local parts = {}
	for part in path:gmatch("[^/]+") do
		if part == ".." then
			table.remove(parts)
		elseif part ~= "." then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return "/"
	end
	return "/" .. table.concat(parts, "/")
end

---@return string parent
function M.dirname(path)
	path = M.normalize(path)
	if path == "/" then
		return "/"
	end
	local parent = path:gsub("/[^/]+$", "")
	if parent == "" then
		return "/"
	end
	return parent
end

return M
