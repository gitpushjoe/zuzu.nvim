local platform = require("zuzu.platform")
local validate = require("zuzu.validate")
local M = {}

---@class (exact) Keymaps
---@field build string[][]
---@field reopen string[]
---@field new_profile string
---@field new_project_profile string
---@field edit_profile string
---@field edit_all_applicable_profiles string
---@field edit_all_profiles string
---@field edit_hooks string
---@field qflist_prev string
---@field qflist_next string
---@field toggle_qflist string
---@field stable_toggle_qflist string

---@class (exact) PathPreferences
---@field root string
---@field atlas_filename string
---@field last_stdout_filename string
---@field last_stderr_filename string
---@field compiler_filename string

---@class (exact) Preferences
---@field build_count integer
---@field display_strategy_count integer
---@field display_strategies (fun(cmd: string, profile: Profile, build_idx: integer, last_stdout_path: string, last_stderr_path: string): nil)[]
---@field path PathPreferences
---@field core_hooks ({[1]: string, [2]: fun(): string})[]
---@field zuzu_function_name string
---@field keymaps Keymaps
---@field prompt_on_simple_edits boolean
---@field reverse_qflist_diagnostic_order boolean
---@field qflist_as_diagnostic boolean
---@field write_on_run boolean
---@field hook_choices_suffix string
---@field compilers [string, string][]

---@param hook_name string
---@return string
local env_var_syntax = function(hook_name)
	return platform.choose("", "env:") .. hook_name
end

---@type Preferences
M.DEFAULT = {
	build_count = 4,
	display_strategy_count = 4,
	keymaps = {
		build = {
			{ "zu", "ZU", "zU", "Zu" },
			{ "zv", "ZV", "zV", "Zv" },
			{ "zs", "ZS", "zS", "Zs" },
			{ "zb", "ZB", "zB", "Zb" },
		},
		reopen = {
			"z.",
			'z"',
			"z:",
		},
		new_profile = "z+",
		new_project_profile = "z/",
		edit_profile = "z=",
		edit_all_applicable_profiles = "z?",
		edit_all_profiles = "z*",
		edit_hooks = "zh",
		qflist_prev = "z[",
		qflist_next = "z]",
		stable_toggle_qflist = "z\\",
		toggle_qflist = "z|",
	},
	display_strategies = {
		require("zuzu.display_strategies").command,
		require("zuzu.display_strategies").split_right,
		require("zuzu.display_strategies").split_below,
		require("zuzu.display_strategies").background,
	},
	path = {
		root = platform.join_path(tostring(vim.fn.stdpath("data")), "zuzu"),
		atlas_filename = "atlas.json",
		last_stdout_filename = "stdout.txt",
		last_stderr_filename = "stderr.txt",
		compiler_filename = "compiler.txt",
	},
	core_hooks = {
		{ env_var_syntax("file"), require("zuzu.hooks").file },
		{ env_var_syntax("dir"), require("zuzu.hooks").directory },
		{ env_var_syntax("parent"), require("zuzu.hooks").parent_directory },
		{ env_var_syntax("base"), require("zuzu.hooks").base },
		{ env_var_syntax("filename"), require("zuzu.hooks").filename },
	},
	zuzu_function_name = "zuzu_cmd",
	prompt_on_simple_edits = false,
	hook_choices_suffix = "__c",
	compilers = {
		--- https://vi.stackexchange.com/a/44620
		{ "python3", '%A %#File "%f"\\, line %l\\, in %o,%Z %#%m' },
		{ "lua", "%E%\\\\?lua:%f:%l:%m,%E%f:%l:%m" },
	},
	reverse_qflist_diagnostic_order = true,
	qflist_as_diagnostic = true,
	write_on_run = true
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
		---assume all lists of 2 items are 2-tuples
		local is_tuple = #src_table == 2
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
		table[key] = table[key] or src_table[key]
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
	local build_count = preferences_table.build_count
	local display_strategy_count = preferences_table.display_strategy_count
	if build_count == 0 then
		return nil, "`build_count` must be at least 1."
	end
	if display_strategy_count == 0 then
		return nil, "`display_strategy_count` must be at least 1."
	end
	if #preferences_table.keymaps.build > display_strategy_count then
		return nil,
			"The length of `keymaps.build` cannot be greater than `display_strategy_count`."
	end
	if #preferences_table.keymaps.build[1] ~= build_count then
		return nil,
			"The length of `keymaps.build[1]` must be equal to `display_strategy_count`."
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
function M.get_compiler_path(preferences)
	return M.join_path(preferences, "compiler" .. platform.EXTENSION)
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
function M.get_last_stdout_path(preferences)
	return M.join_path(preferences, preferences.path.last_stdout_filename)
end

---@param preferences Preferences
---@return string
function M.get_last_stderr_path(preferences)
	return M.join_path(preferences, preferences.path.last_stderr_filename)
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
function M.bind_keymaps(preferences)
	local set_keymap = function(keymap, action, description)
		if keymap == "" then
			return
		end
		vim.api.nvim_set_keymap(
			"n",
			keymap,
			"<cmd>lua require('zuzu')." .. action .. "<CR>",
			{ noremap = true, silent = true, desc = description }
		)
	end
	local keymaps = preferences.keymaps
	for display_strategy_idx, builds in ipairs(keymaps.build) do
		for build_idx, keymap in ipairs(builds) do
			set_keymap(
				keymap,
				("run(%s, %s)"):format(build_idx, display_strategy_idx),
				("zuzu: Run build #%s with style #%s"):format(
					build_idx,
					display_strategy_idx
				)
			)
		end
	end
	for display_strategy_idx, keymap in ipairs(keymaps.reopen) do
		set_keymap(
			keymap,
			("reopen(%s)"):format(display_strategy_idx),
			("zuzu: Show last ouput with style #%s"):format(
				display_strategy_idx
			)
		)
	end
	set_keymap(
		keymaps.new_profile,
		"new_profile()",
		"zuzu: Create new build profile"
	)
	set_keymap(
		keymaps.new_project_profile,
		"new_project_profile()",
		"zuzu: Create new profile for project"
	)
	set_keymap(keymaps.edit_profile, "edit_profile()", "zuzu: Edit profile")
	set_keymap(
		keymaps.edit_all_applicable_profiles,
		"edit_all_applicable_profiles()",
		"zuzu: Edit all applicable profiles"
	)
	set_keymap(
		keymaps.edit_all_profiles,
		"edit_all_profiles()",
		"zuzu: Edit all profiles"
	)
	set_keymap(keymaps.edit_hooks, "edit_hooks()", "zuzu: Edit hooks")
	set_keymap(
		keymaps.stable_toggle_qflist,
		"toggle_qflist(true)",
		"zuzu: Toggle error window"
	)
	set_keymap(
		keymaps.toggle_qflist,
		"toggle_qflist(false)",
		"zuzu: Toggle error window"
	)
	set_keymap(
		keymaps.qflist_prev,
		"qflist_prev_or_next(false)",
		"zuzu: Toggle error window"
	)
	set_keymap(
		keymaps.qflist_next,
		"qflist_prev_or_next(true)",
		"zuzu: Toggle error window"
	)
end

return M
