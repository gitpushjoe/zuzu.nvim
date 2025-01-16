local M = {}

M.ALL_FILETYPES = 0

---@class Profile
---@field [1] integer depth
---@field [2] string[] filetypes
---@field [3] string[] hooks
---@field [4] string setup
---@field [5] string[] builds

---@param profile Profile
---@return integer
function M.depth(profile)
	return profile[1] == -1 and math.huge or profile[1]
end

---@param profile Profile
---@return string[]
function M.filetypes(profile)
	return profile[2]
end

---@param profile Profile
---@return string[]
function M.hooks(profile)
	return profile[3]
end

---@param profile Profile
---@param extension string
---@return boolean
function M.accepts_ext(profile, extension)
	local filetypes = M.filetypes(profile)
	if #filetypes == 0 then
		return false
	end
	for _, filetype in ipairs(filetypes) do
		if extension == filetype then
			return true
		end
	end
	return false
end

---@param profile Profile
---@param depth integer
---@param extension string
---@return boolean
function M.accepts(profile, depth, extension)
	return depth <= M.depth(profile) and M.accepts_ext(profile, extension)
end

return M
