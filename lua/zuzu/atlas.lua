local Profile = require("zuzu.profile")
local platform = require("zuzu.platform")
local ProfileMap = require("zuzu.profile_map")
local utils = require("zuzu.utils")
local M = {}

---@alias Atlas table<string, Profile[]>

---@param atlas Atlas
---@param path string
---@return fun(): Profile?, string?
function M.resolve_profile_generator(atlas, path)
	return coroutine.wrap(function()
		local directory, _, extension =
			utils.get_parent_directory_basename_extension(path)

		---@param key string?
		---@param depth integer
		local find_first_accepting_profile = function(key, depth)
			local group = atlas[key]
			if not group then
				return
			end
			for _, profile in ipairs(group) do
				if Profile.accepts(profile, depth, extension) then
					coroutine.yield(profile, key)
				end
			end
		end

		local current_depth = 0
		local profile = find_first_accepting_profile(path, current_depth)
			or find_first_accepting_profile(directory, current_depth)
		current_depth = 1
		if profile then
			coroutine.yield(profile, path)
		end

		for _ = 1, 1024 do
			if not directory then
				return
			end
			current_depth = current_depth + 1
			directory, _ =
				directory:match("(.*)" .. platform.PATH_SEP .. "(.*)")
			if atlas[directory] then
				profile = find_first_accepting_profile(directory, current_depth)
				if profile then
					coroutine.yield(profile, directory)
				end
			end
			if not directory or #directory == 0 then
				return
			end
		end
	end)
end

---@param atlas Atlas
---@param path string
---@return Profile? profile
---@return string? root
function M.resolve_profile(atlas, path)
	local gen = M.resolve_profile_generator(atlas, path)
	local profile, root = gen()
	if profile then
		return profile, root
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
	table.sort(atlas[root], function(profile1, profile2)
		local profile1_filetypes = #Profile.filetypes(profile1)
		profile1_filetypes = profile1_filetypes == 0 and math.huge
			or profile1_filetypes
		local profile2_filetypes = #Profile.filetypes(profile2)
		profile2_filetypes = profile2_filetypes == 0 and math.huge
			or profile2_filetypes
		if profile1_filetypes < profile2_filetypes then
			return true
		end
		if profile1_filetypes > profile2_filetypes then
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

---@param atlas_path string
function M.atlas_read(atlas_path)
	local handle = io.open(atlas_path)
	if not handle then
		handle = utils.assert(
			io.open(atlas_path, "w"),
			"Could not create file " .. atlas_path
		)
		handle:close()
		handle = utils.assert(io.open(atlas_path, "r"))
	end
	local text = handle:read("*a")
	handle:close()
	local _, table = pcall(function()
		return (text == "" or text == "[]") and {} or vim.fn.json_decode(text)
	end)
	return table or {}
end

---@param atlas Atlas
---@param atlas_path string
function M.atlas_write(atlas, atlas_path)
	local atlas_handle = utils.assert(io.open(atlas_path, "w"))
	utils.assert(atlas_handle:write(vim.fn.json_encode(atlas)))
	atlas_handle:close()
end

return M
