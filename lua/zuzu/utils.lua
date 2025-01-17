local platform = require("zuzu.platform")

local M = {}

M.get_parent_directory_basename_extension = function(path)
	-- TODO(gitpushjoe): add error checking
	return path:match("(.*)" .. platform.PATH_SEP .. "(.*)%.(%w*)")
end

return M
