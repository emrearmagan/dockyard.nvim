local text_parser = require("dockyard.loglens.parsers.text")
local json_parser = require("dockyard.loglens.parsers.json")

local M = {}

---@param source LogSource
---@return LogLensParserSession|nil
---@return string|nil
function M.create_session(source)
	if source.parser == "text" then
		return text_parser.create(source), nil
	end
	if source.parser == "json" then
		return json_parser.create(source), nil
	end
	return nil, "Unsupported parser. Use 'text' or 'json'"
end

return M
