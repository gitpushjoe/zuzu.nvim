local platform = require("zuzu.platform")

local M = {}

M.get_parent_directory_basename_extension = function(path)
	return path:match("(.*)" .. platform.PATH_SEP .. "(.*)%.(%w*)")
end

---@param err string?
M.error = function(err)
	vim.notify("zuzu: " .. (err or ""), vim.log.levels.ERROR)
	error(nil, 0)
end

---@generic T
---@param expr T?
---@param errmsg string?
---@return T
M.assert = function(expr, errmsg)
	if not expr then
		M.error(errmsg)
	end
	return expr
end

return M
