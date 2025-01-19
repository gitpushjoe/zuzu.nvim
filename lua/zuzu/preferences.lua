local platform = require("zuzu.platform")
local validate = require("zuzu.validate")
local M = {}

---@class (exact) Keybinds
---@field build string[][]
---@field reopen string[]
---@field new_profile string
---@field new_project_profile string
---@field edit_profile string
---@field edit_all_applicable_profiles string
---@field edit_all_profiles string
---@field edit_hooks string

---@class (exact) PathPreferences
---@field root string
---@field atlas_filename string
---@field last_output_filename string

---@class (exact) Preferences
---@field profile_count integer
---@field display_strategy_count integer
---@field display_strategies (fun(string): nil)[]
---@field path PathPreferences
---@field core_hooks ({[1]: string, [2]: fun(): string})[]
---@field zuzu_function_name string
---@field keybinds Keybinds
---@field prompt_on_simple_edits boolean
---@field hook_choices_suffix string

---@type Preferences
M.DEFAULT = {
	profile_count = 4,
	display_strategy_count = 3,
	keybinds = {
		build = {
			{ "zu", "ZU", "zU", "Zu" },
			{ "zv", "ZV", "zV", "Zv" },
			{ "zs", "ZS", "zS", "Zs" },
		},
		reopen = {
			"z,",
			'z"',
			"z:",
		},
		new_profile = "z+",
		new_project_profile = "z/",
		edit_profile = "z=",
		edit_all_applicable_profiles = "z?",
		edit_all_profiles = "z*",
		edit_hooks = "zh",
	},
	display_strategies = {
		require("zuzu.display_strategies").command,
		require("zuzu.display_strategies").split_right,
		require("zuzu.display_strategies").split_below,
	},
	path = {
		root = platform.join_path(tostring(vim.fn.stdpath("data")), "zuzu"),
		atlas_filename = "atlas.json",
		last_output_filename = "last.txt",
	},
	core_hooks = {
		{ "file", require("zuzu.hooks").file },
		{ "dir", require("zuzu.hooks").directory },
		{ "parent", require("zuzu.hooks").parent_directory },
		{ "base", require("zuzu.hooks").base },
		{ "filename", require("zuzu.hooks").filename },
	},
	zuzu_function_name = "zuzu_cmd",
	prompt_on_simple_edits = false,
	hook_choices_suffix = "__c",
}

---@function function_name string
---@function arg_name string
---@function src_table table
---@function table table
---@return table?
---@return string? errmsg
M.table_join = function(function_name, arg_name, src_table, table)
	local err
	if not table then
		return
	end
	local is_array = src_table[1] ~= nil
	if is_array then
		---assume all lists where the first 2 items are different are 2-tuples
		local is_tuple = type(src_table[1]) ~= type(src_table[2])
		if is_tuple then
			err = validate.types(function_name, {
				{ table[1], type(src_table[1]), arg_name .. "[1]" },
				{ table[2], type(src_table[2]), arg_name .. "[2]" },
			})
			if err then
				return nil, err
			end
			src_table[1] = table[1]
			src_table[2] = table[2]
			return src_table
		end
		local expected_type = type(src_table[1])
		local isnt_list_of_tables = expected_type ~= type({})
		if isnt_list_of_tables then
			err = validate.types_in_list(
				function_name,
				table,
				arg_name,
				expected_type
			)
			if err then
				return nil, err
			end
			return src_table
		end
		for i, item in ipairs(table) do
			_, err = M.table_join(
				function_name,
				("%s[%s]"):format(arg_name, i),
				src_table[1],
				item
			)
			if err then
				return nil, err
			end
			src_table[i] = table[i]
		end
	end
	err = validate.types(function_name, { { table, "table", arg_name } })
	if err then
		return nil, err
	end
	for key, item in pairs(src_table) do
		if type(item) ~= type({}) then
			err = validate.types(function_name, {
				{
					table[key],
					type(item) .. "?",
					("%s.%s"):format(arg_name, key),
				},
			})
		else
			_, err = M.table_join(
				function_name,
				("%s.%s"):format(arg_name, key),
				item,
				table[key]
			)
		end
		if err then
			return nil, err
		end
		src_table[key] = table[key] or src_table[key]
	end
	return src_table
end

---@param function_name string
---@param table table
---@return Preferences?
---@return string? errmsg
function M.new(function_name, table)
	local preferences_table, err =
		M.table_join(function_name, "{table}", M.DEFAULT, table)
	if not preferences_table then
		return nil, err
	end
	---@cast preferences_table Preferences
	local root = preferences_table.path.root
	if root:sub(#root, #root) == platform.PATH_SEP then
		preferences_table.path.root = root:sub(1, #root - 1)
	end
	local profile_count = preferences_table.profile_count
	local display_strategy_count = preferences_table.display_strategy_count
	if profile_count == 0 then
		return nil, "`profile_count` must be at least 1."
	end
	if display_strategy_count == 0 then
		return nil, "`display_strategy_count` must be at least 1."
	end
	if #preferences_table.keybinds.build > display_strategy_count then
		return nil,
			"The length of `keybinds.build` cannot be greater than `display_strategy_count`."
	end
	if #preferences_table.keybinds.build[1] ~= profile_count then
		return nil,
			"The length of `keybinds.build[1]` must be equal to `display_strategy_count`."
	end
	if #preferences_table.display_strategies ~= display_strategy_count then
		return nil,
			"The length of `display_strategies` must equal `display_strategy_count`."
	end
	return preferences_table
end

---@param preferences Preferences
---@vararg string
---@return string
function M.join_path(preferences, ...)
	return platform.join_path(preferences.path.root, ...)
end

---@param preferences Preferences
---@return string
function M.get_atlas_path(preferences)
	return M.join_path(preferences, preferences.path.atlas_filename)
end

---@param preferences Preferences
---@return string
function M.get_hooks_path(preferences)
	return M.join_path(preferences, "hooks" .. platform.EXTENSION)
end

---@param preferences Preferences
---@return string
function M.get_setup_path(preferences)
	return M.join_path(preferences, "setup" .. platform.EXTENSION)
end

---@param preferences Preferences
---@return string
function M.get_builds_path(preferences)
	return M.join_path(preferences, "builds")
end

---@param preferences Preferences
---@param name string
---@return string
function M.get_build_path(preferences, name)
	return M.join_path(preferences, "builds", name .. platform.EXTENSION)
end

---@param preferences Preferences
---@return string
function M.get_last_path(preferences)
	return M.join_path(preferences, preferences.path.last_output_filename)
end

---@param preferences Preferences
function M.initialize(preferences)
	if vim.fn.isdirectory(preferences.path.root) == 0 then
		vim.fn.mkdir(preferences.path.root, "p")
	end
	if vim.fn.isdirectory(M.get_builds_path(preferences)) == 0 then
		vim.fn.mkdir(M.get_builds_path(preferences), "p")
	end
end

---@param preferences Preferences
function M.bind_keybinds(preferences)
	local set_keybind = function(keybind, action, description)
		if keybind == "" then
			return
		end
		vim.api.nvim_set_keymap(
			"n",
			keybind,
			"<cmd>lua require('zuzu')." .. action .. "<CR>",
			{ noremap = true, silent = true, desc = description }
		)
	end
	local keybinds = preferences.keybinds
	for display_strategy_idx, builds in ipairs(keybinds.build) do
		for build_idx, keybind in ipairs(builds) do
			set_keybind(
				keybind,
				("run(%s, %s)"):format(build_idx, display_strategy_idx),
				("zuzu: Run build #%s with style #%s"):format(
					build_idx,
					display_strategy_idx
				)
			)
		end
	end
	for display_strategy_idx, keybind in ipairs(keybinds.reopen) do
		set_keybind(
			keybind,
			("reopen(%s)"):format(display_strategy_idx),
			("zuzu: Show last ouput with style #%s"):format(
				display_strategy_idx
			)
		)
	end
	set_keybind(
		keybinds.new_profile,
		"new_profile()",
		"zuzu: Create new build profile"
	)
	set_keybind(
		keybinds.new_project_profile,
		"new_project_profile()",
		"zuzu: Create new profile for project"
	)
	set_keybind(keybinds.edit_profile, "edit_profile()", "zuzu: Edit profile")
	set_keybind(
		keybinds.edit_all_applicable_profiles,
		"edit_all_applicable_profiles()",
		"zuzu: Edit all applicable profiles"
	)
	set_keybind(
		keybinds.edit_all_profiles,
		"edit_all_profiles()",
		"zuzu: Edit all profiles"
	)
	set_keybind(
		keybinds.edit_hooks,
		"edit_hooks()",
		"zuzu: Edit hooks"
	)
end

return M
