local M = {}

---@class (exact) PlatformHandler<T>
---@field win function(): T
---@field sh function(): T

M.PATH_SEP = package.config:sub(1, 1)

M.PLATFORM = (function()
	local handle = assert(io.popen("uname"))
	local uname = handle:read("*a")
	handle:close()
	return uname:sub(1, 5) == "Linux" and "sh" or "win"
end)()

---@param handler PlatformHandler
M.handle = function(handler)
	return handler[M.PLATFORM]()
end

---@vararg string
M.join_path = function(...)
	local paths = { ... }
	return table.concat(paths, M.PATH_SEP)
end

return M
