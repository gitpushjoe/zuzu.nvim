local Profile = require("zuzu.profile")
local platform = require("zuzu.platform")
local ProfileMap = require("zuzu.profile_map")
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
	profile = find_first_accepting_profile(path, current_depth)
		or find_first_accepting_profile(directory, current_depth)
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

---@param atlas Atlas
---@param profile_id string
---@return Profile?
function M.find_by_id(atlas, profile_id)
	local root = ProfileMap.split_id(profile_id)
	if not root then
		return
	end
	local profile_group = atlas[root]
	if not profile_group then
		return
	end
	for _, profile in ipairs(profile_group) do
		if ProfileMap.get_id(root, profile) == profile_id then
			return profile
		end
	end
end

---@param atlas Atlas
---@param root string
---@param profile Profile
function M.insert(atlas, root, profile)
	if not atlas[root] or #atlas[root] == 0 then
		atlas[root] = { profile }
		return
	end
	table.insert(atlas[root], profile)
	--- TODO(gitpushjoe): optimize this for always-sorted inserts
	table.sort(atlas, function(profile1, profile2)
		if #Profile.filetypes(profile1) < #Profile.filetypes(profile2) then
			return true
		end
		if #Profile.filetypes(profile1) > #Profile.filetypes(profile2) then
			return false
		end
		return Profile.depth(profile1) < Profile.depth(profile2)
	end)
end

---@param atlas Atlas
---@param root string
---@param profile Profile
---@return boolean
function M.delete(atlas, root, profile)
	if not atlas[root] or #atlas[root] == 0 then
		return false
	end
	for i, found_profile in ipairs(atlas[root]) do
		if found_profile == profile then
			table.remove(atlas[root], i)
			if #atlas[root] == 0 then
				atlas[root] = nil
			end
			return true
		end
	end
	return false
end

return M
