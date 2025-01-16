local Profile = require("zuzu.profile")
local platform = require("zuzu.platform")
local M = {}

---@alias Atlas table<string, Profile[]>

---@param atlas Atlas
---@param path string
---@return Profile? profile
---@return string? path
function M.resolve_profile(atlas, path)
	-- TODO(gitpushjoe): assert path exists, and has extension
	local directory, _, extension =
		path:match("(.*)" .. platform.PATH_SEP .. "(.*)%.(%w*)")

	---@param dir string?
	---@param depth integer
	local find_first_accepting_profile = function(dir, depth)
		local group = atlas[dir]
		if not group then
			return
		end
		for _, profile in ipairs(group) do
			if Profile.accepts(profile, depth, extension) then
				return profile, directory
			end
		end
	end

	local current_depth = 0
	local profile = nil
	profile = find_first_accepting_profile(directory, current_depth)
	if profile then
		return profile
	end

	for _ = 1, 1024 do
		directory, _ = directory:match("(.*)" .. platform.PATH_SEP .. "(.*)")
		current_depth = current_depth + 1
		if atlas[directory] then
			profile = find_first_accepting_profile(directory, current_depth)
			if profile then
				return profile
			end
		end
		if #directory == 0 then
			break
		end
	end
end

return M
