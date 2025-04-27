local M = {}

M.PATH_SEP = package.config:sub(1, 1)

M.PLATFORM = M.PATH_SEP == "/" and "unix" or "win"

---@generic T
---@param unix_callback fun(...): T
---@param win_callback fun(...): T
M.dispatch = function(unix_callback, win_callback)
	return M.PLATFORM == "unix" and unix_callback() or win_callback()
end

---@generic T
---@param unix_version T
---@param win_version T
M.choose = function(unix_version, win_version)
	return M.PLATFORM == "unix" and unix_version or win_version
end

M.EXTENSION = M.choose(".sh", ".ps1")

M.NEWLINE = M.choose("\n", "\r\n")

---@vararg string
M.join_path = function(...)
	local paths = { ... }
	return table.concat(paths, M.PATH_SEP)
end

M.SHELL_IS_BASH = (function()
	if M.PLATFORM ~= "unix" then
		return false
	end
	local phandle = assert(io.popen("echo -n $SHELL"))
	local ret = phandle:read("*a"):sub(-4, -1) == "bash"
	phandle:close()
	return ret
end)()

return M
