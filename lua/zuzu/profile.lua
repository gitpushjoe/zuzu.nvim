local platform = require("zuzu.platform")
local utils = require("zuzu.utils")
local M = {}

---@class (exact) Profile
---@field [1] string[] filetypes
---@field [2] integer depth
---@field [3] string[][] hooks
---@field [4] string setup
---@field [5] string[] builds
---@field [6] string? compiler

---@param root string
---@param filetypes string
---@param depth string
---@param hooks string[]
---@param setup string
---@param builds string[]
---@param compiler string?
---@param hook_choices_suffix string
---@return Profile
---@return string root_name
function M.new(
	root,
	filetypes,
	depth,
	hooks,
	setup,
	builds,
	compiler,
	hook_choices_suffix
)
	utils.assert(
		root ~= "",
		"Unexpected empty root. Use {{ root: * }} to target all files."
	)
	if root ~= "*" then
		local handle = io.open(root, "r")
		utils.assert(
			root:sub(1, 1) ~= ".",
			("Do not use relative paths in root."):format(root)
		)
		utils.assert(
			(root:sub(1, 1) ~= "." and handle ~= nil)
				or vim.fn.isdirectory(root),
			("Root does not exist: %s."):format(root)
		)
		if handle then
			handle:close()
		end
	else
		root = ""
	end
	root = root:sub(#root, #root) == "/" and root:sub(1, #root - 1) or root

	utils.assert(
		filetypes ~= "",
		"Unexpected empty filetypes. Use {{ filetypes: * }} to target all filetypes."
	)
	local filetype_list = filetypes == "*" and {} or vim.split(filetypes, ",")
	table.sort(filetype_list)
	for _, filetype in ipairs(filetype_list) do
		utils.assert(
			filetype ~= "",
			("Unexpected empty string in filetypes list: %s. Do not use a trailing comma."):format(
				filetypes
			)
		)
	end

	local depth_value = tonumber(depth)
	utils.assert(
		depth_value ~= math.huge,
		("Invalid depth: %s. Use -1 for any depth."):format(depth)
	)
	utils.assert(
		depth_value ~= nil and math.floor(depth_value) == depth_value,
		("Invalid depth: %s."):format(depth)
	)

	---@type string[][]
	local hook_list = {}
	for _, hook in ipairs(hooks) do
		(function()
			if hook == "" then
				return
			end
			local export_pattern_syntax =
				platform.choose("^export (%S-)=", "^$(%S-)%s?=%s?")
			local hook_name, hook_val =
				hook:match(export_pattern_syntax .. '"(.*)"$')
			if hook_name then
				return table.insert(hook_list, { hook_name, hook_val })
			end
			hook_name, hook_val = hook:match(export_pattern_syntax .. "'(.*)'$")
			if hook_name then
				return table.insert(hook_list, { hook_name, hook_val })
			end
			hook_name, hook_val = hook:match(export_pattern_syntax .. "(%S-)$")
			if hook_name then
				return table.insert(hook_list, { hook_name, hook_val })
			end
			hook_name, hook_val = hook:match(export_pattern_syntax .. "(.-)$")
			if utils.str_ends_with(hook_name, hook_choices_suffix) then
				return table.insert(hook_list, { hook_name, hook_val })
			end
			utils.error(
				("Could not parse hook: %s. Format is " .. platform.choose(
					"`export name=value`",
					"`$VAR = value`"
				) .. "."):format(hook)
			)
		end)()
	end

	local parsed_builds = {}
	for _, build in ipairs(builds) do
		utils.assert(
			build:sub(1, 1) ~= "|",
			'Build script cannot start with "|"'
		)
		local name, rest = string.match(
			build,
			"^### {{ name: ([%w_-%.]+) }}" .. platform.NEWLINE .. "(.*)$"
		)
		if name then
			build = string.format("|%s|%s", name, rest)
		end
		table.insert(parsed_builds, build)
	end
	return {
		filetype_list,
		depth_value,
		hook_list,
		setup,
		parsed_builds,
		compiler
	},
		root
end

---@param profile Profile
---@return string[]
function M.filetypes(profile)
	return profile[1]
end

---@param profile Profile
---@return integer
function M.depth(profile)
	return profile[2] == -1 and math.huge or profile[2]
end

---@param profile Profile
---@return string[][]
function M.hooks(profile)
	return profile[3]
end

---@param profile Profile
---@return string
function M.setup(profile)
	return profile[4]
end

---@param profile Profile
---@return string[]
function M.builds(profile)
	return profile[5]
end

---@param profile Profile
---@param build_idx integer
---@return string
function M.build(profile, build_idx)
	return M.builds(profile)[build_idx] or platform.NEWLINE
end

---@param profile Profile
---@return string?
function M.compiler(profile)
	return profile[6]
end

---@param profile Profile
---@param compiler_pairs [string, string][]
---@return string?
function M.get_errorformat(profile, compiler_pairs)
	local target_compiler = M.compiler(profile)
	if not target_compiler then
		return
	end
	for _, compiler_pair in ipairs(compiler_pairs) do
		local compiler = compiler_pair[1]
		local errorformat = compiler_pair[2]
		if compiler == target_compiler then
			return errorformat
		end
	end
end

---@param profile1 Profile
---@param profile2 Profile
---@return boolean
function M.equals(profile1, profile2)
	return M.depth(profile1) == M.depth(profile2)
		and M.setup(profile1) == M.setup(profile2)
		and #M.filetypes(profile1) == #M.filetypes(profile2)
		and M.compiler(profile1) == M.compiler(profile2)
		and (function()
			for i = 1, #M.filetypes(profile1) do
				if M.filetypes(profile1)[i] ~= M.filetypes(profile2)[i] then
					return false
				end
			end
			return true
		end)()
		and #M.hooks(profile1) == #M.hooks(profile2)
		and (function()
			for i = 1, #M.hooks(profile1) do
				if
					M.hooks(profile1)[i][1] ~= M.hooks(profile2)[i][1]
					or M.hooks(profile1)[i][2] ~= M.hooks(profile2)[i][2]
				then
					return false
				end
			end
			return true
		end)()
		and #M.builds(profile1) == #M.builds(profile2)
		and (function()
			for i = 1, #M.builds(profile1) do
				if M.build(profile1, i) ~= M.build(profile2, i) then
					return false
				end
			end
			return true
		end)()
end

---@param target_profile Profile
---@param src_profile Profile
function M.set(target_profile, src_profile)
	target_profile[1] = {}
	table.move(
		M.filetypes(src_profile),
		1,
		#M.filetypes(src_profile),
		1,
		M.filetypes(target_profile)
	)
	target_profile[2] = src_profile[2]
	target_profile[3] = {}
	for _, hook_pair in ipairs(M.hooks(src_profile)) do
		table.insert(target_profile[3], { hook_pair[1], hook_pair[2] })
	end
	target_profile[4] = src_profile[4]
	target_profile[5] = {}
	table.move(
		M.builds(src_profile),
		1,
		#M.builds(src_profile),
		1,
		M.builds(target_profile)
	)
	target_profile[6] = src_profile[6]
end

---@param profile Profile
---@param extension string
---@return boolean
function M.accepts_ext(profile, extension)
	local filetypes = M.filetypes(profile)
	if #filetypes == 0 then
		return true
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

---@param profile Profile
---@param build_idx integer
---@return string build_name
---@return string build_text
function M.build_info(profile, build_idx)
	local build = M.build(profile, build_idx)
	if build:sub(1, 1) == "|" then
		local name, text = build:match("|(.-)|(.*)")
		return name, text
	end
	return tostring(build_idx), build
end

return M
