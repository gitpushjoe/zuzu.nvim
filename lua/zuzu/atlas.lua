local Profile = require("zuzu.profile")
local M = {}

local PATH_SEP = package.config:sub(1, 1)

---@type Atlas table<string, Profile[]>

---@param atlas Atlas
---@param path string
---@return Profile? profile
---@return string? path
function M.resolve_profile(atlas, path)
	-- TODO(gitpushjoe): assert path exists, and has extension
	local directory, _, extension =
		path:match("(.*)" .. PATH_SEP .. "(.*)%.(%w*)")
	local current_depth = 0
	if atlas[directory] then
		for _, profile in ipairs(atlas[directory]) do
			if Profile.accepts(profile, current_depth, extension) then
				return profile, directory
			end
		end
	end
	for _ = 1, 1024 do
		directory, _ = directory:match("(.*)" .. PATH_SEP .. "(.*)")
		if atlas[directory] then
			for _, profile in ipairs(atlas[directory]) do
				print(profile, current_depth, extension)
				if Profile.accepts(profile, current_depth, extension) then
					return profile, directory
				end
			end
		end
		if #directory == 0 then
			break
		end
	end
end

return M
