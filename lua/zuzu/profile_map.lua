local Profile = require("zuzu.profile")
local M = {}

---@alias ProfileMap table<string, Profile>

---@return ProfileMap
function M.new()
	return {}
end

---@param profile Profile
---@return string
function M.get_id(root, profile)
	return root
		.. "\n"
		.. table.concat(Profile.filetypes(profile), ",")
		.. "\n"
		.. Profile.depth(profile)
end

---@param profile_map ProfileMap
---@param root string
---@param profile Profile
---@return ProfileMap
function M.map_insert(profile_map, root, profile)
	profile_map[M.get_id(root, profile)] = profile
	return profile_map
end

---@param id string
---@return string? root
---@return string? filetypes
---@return string? depth
function M.split_id(id)
	return string.match(id, "(.*)\n(.*)\n(.*)")
end

return M
