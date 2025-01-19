local Profile = require("zuzu.profile")
local Atlas = require("zuzu.atlas")
local platform = require("zuzu.platform")
local ProfileEditor = require("zuzu.profile_editor")
local Preferences = require("zuzu.preferences")
local ProfileMap = require("zuzu.profile_map")
local utils = require("zuzu.utils")
local M = {}

---@class (exact) BuildPair
---@field [1] Profile profile
---@field [2] integer build index

---@class (exact) HookCallback
---@field [1] string name
---@field [2] fun(...): string callback

---@class (exact) HookPair
---@field [1] string name
---@field [2] string callback

---@class (exact) State
---@field atlas Atlas
---@field hooks HookPair[]
---@field profile Profile?
---@field preferences Preferences
---@field build_cache table<string, BuildPair>
---@field hooks_is_dirty boolean
---@field core_hooks_is_dirty boolean
---@field profile_editor ProfileEditor

---@return HookCallback[]
function M.DEFAULT_CORE_HOOK_CALLBACKS()
	return {
		{
			"file",
			function()
				return vim.fn.expand("%:p")
			end,
		},
		{
			"dir",
			function()
				return vim.fn.expand("%:p:h")
			end,
		},
		{
			"parent",
			function()
				return vim.fn.expand("%:p:h:h")
			end,
		},
	}
end

---@param state State
---@return string
function M.state_write_hooks(state)
	local text = ""
	for _, hook_pair in ipairs(state.hooks) do
		local hook_name = hook_pair[1]
		local hook_val = hook_pair[2]
		text = text
			.. platform
				.choose("export %s='%s'\n", "$env:%s = '%s'\n")
				:format(hook_name, hook_val:gsub("'", "'\\''"))
	end

	local hooks_handle = utils.assert(
		io.open(Preferences.get_hooks_path(state.preferences), "w")
	)
	utils.assert(hooks_handle:write(text))
	hooks_handle:close()

	return text
end

---@param state State
function M.state_write_setup(state)
	local setup_handle = utils.assert(
		io.open(Preferences.get_setup_path(state.preferences), "w")
	)
	utils.assert(setup_handle:write(Profile.setup(state.profile)))
	setup_handle:close()
end

---@param state State
---@param name string
---@param text string
---@param build_idx integer
function M.state_write_build(state, name, text, build_idx)
	text = platform.choose("source %s\nsource %s\n", '. "%s"\n. "%s"\n'):format(
		Preferences.get_hooks_path(state.preferences),
		Preferences.get_setup_path(state.preferences)
	) .. ("function %s {\n:\n%s\n}\n%s 2>&1 | tee %s"):format(
		state.preferences.zuzu_function_name,
		text,
		state.preferences.zuzu_function_name,
		Preferences.get_last_path(state.preferences)
	)
	local build_handle = utils.assert(
		io.open(Preferences.get_build_path(state.preferences, name), "w+")
	)
	utils.assert(build_handle:write(text))
	build_handle:close()
	state.build_cache[name] = { state.profile, build_idx }
	return text
end

---@param state State
function M.state_resolve_hooks(state)
	local new_hooks = {}
	-- invariants:
	-- # of core hooks does not change
	-- core hook callbacks do not change
	-- core hooks are always at the beginning of state.hooks
	for i, hook_pair in ipairs(state.preferences.core_hooks) do
		local hook_name = hook_pair[1]
		local hook_func = hook_pair[2]
		local hook_val = hook_func()
		table.insert(new_hooks, { hook_name, hook_val })
		state.core_hooks_is_dirty = state.core_hooks_is_dirty
			or hook_val ~= state.hooks[i][2]
	end
	local hooks = Profile.hooks(state.profile)
	local hooks_is_dirty = state.core_hooks_is_dirty
		or #hooks ~= #state.hooks - #new_hooks
	for _, hook_pair in ipairs(hooks) do
		local idx = #new_hooks + 1
		new_hooks[idx] = { hook_pair[1], hook_pair[2] }
		hooks_is_dirty = hooks_is_dirty
			or (
				new_hooks[idx][1] ~= state.hooks[idx][1]
				or new_hooks[idx][2] ~= state.hooks[idx][2]
			)
	end
	state.core_hooks_is_dirty = false
	state.hooks_is_dirty = hooks_is_dirty
	state.hooks = new_hooks
end

---@param state State
---@param path string
---@param build_idx integer
---@return string? cmd
---@return string? errmsg
function M.state_build(state, path, build_idx)
	local profile = Atlas.resolve_profile(state.atlas, path)
	if not profile then
		return nil, "No applicable build profile found."
	end
	state.profile = profile
	M.state_resolve_hooks(state)
	if state.hooks_is_dirty then
		M.state_write_hooks(state)
		state.hooks_is_dirty = false
	end
	local build_name, build_text = Profile.build_info(profile, build_idx)
	local build = state.build_cache[build_name]
	local build_file_is_dirty = not (
		build
		and build[1] == profile
		and build[2] == build_idx
	)
	if build_file_is_dirty then
		M.state_write_setup(state)
		M.state_write_build(state, build_name, build_text, build_idx)
	end
	return "source "
		.. platform.join_path(
			state.preferences.path.root,
			"builds",
			build_name .. "." .. platform.EXTENSION
		)
end

---@param state State
---@param root string
function M.state_edit_new_profile(state, root)
	ProfileEditor.editor_open_new_profile(state.profile_editor, root)
end

---@param state State
---@param root string
function M.state_edit_new_profile_at_directory(state, root)
	ProfileEditor.editor_open_new_profile_at_directory(
		state.profile_editor,
		root
	)
end

---@param state State
---@param path string
function M.state_edit_most_applicable_profile(state, path)
	local profile, root = Atlas.resolve_profile(state.atlas, path)
	profile = utils.assert(profile, "No applicable profile found.")
	ProfileEditor.editor_open(
		state.profile_editor,
		{ [ProfileMap.get_id(root, profile)] = profile },
		true
	)
end

---@param state State
function M.state_edit_all_profiles(state)
	local profile_map = {}
	for root, profiles in pairs(state.atlas) do
		for _, profile in ipairs(profiles) do
			profile_map[ProfileMap.get_id(root, profile)] = profile
		end
	end
	ProfileEditor.editor_open(state.profile_editor, profile_map, true)
end

---@param state State
---@param path string
function M.state_edit_all_applicable_profiles(state, path)
	local profile_map = {}
	for profile, root in Atlas.resolve_profile_generator(state.atlas, path) do
		profile_map[ProfileMap.get_id(root, profile)] = profile
	end
	ProfileEditor.editor_open(state.profile_editor, profile_map, true)
end

---@param state State
---@param path string
function M.state_edit_hooks(state, path)
	local profile = utils.assert(
		Atlas.resolve_profile(state.atlas, path),
		"No applicable build profile found."
	)

	local hooks = Profile.hooks(profile)
	if #hooks == 0 then
		utils.error("This profile has no hooks.")
		return
	end

	local choices = {}
	for _, hook_pair in ipairs(hooks) do
		local hook_name = hook_pair[1]
		if
			not utils.str_ends_with(
				hook_name,
				state.preferences.hook_choices_suffix
			)
		then
			table.insert(choices, hook_name)
		end
	end
	utils.create_floating_options_window(
		choices,
		"zuzu///hooks",
		function(hook_name)
			return (':bd! | lua require("zuzu").edit_hook("%s")<CR>'):format(
				hook_name
			)
		end
	)
end

---@param state State
---@param path string
---@param hook_name string
function M.state_edit_hook(state, path, hook_name)
	local profile = utils.assert(
		Atlas.resolve_profile(state.atlas, path),
		"No applicable build profile found."
	)

	local hook_idx, hook_val, hook_choices
	local direct_set = false

	if utils.str_starts_with(hook_name, "\ndirect-set\n") then
		hook_name = hook_name:sub(#"\ndirect-set\n" + 1, #hook_name)
		direct_set = true
	end
	hook_idx, hook_val, hook_choices = (function()
		for i, hook_pair in ipairs(Profile.hooks(profile)) do
			if hook_pair[1] == hook_name then
				hook_idx = i
				hook_val = hook_pair[2]
			elseif
				not direct_set
				and hook_pair[1]
					== hook_name .. state.preferences.hook_choices_suffix
			then
				hook_choices = hook_pair[2]
			end
		end
		if hook_idx then
			return hook_idx, hook_val, hook_choices
		end
		utils.error(('Could not find hook "%s"'):format(hook_name))
	end)()

	if hook_choices then
		local cmd = platform
			.choose(
				[[
array=%s; for item in "${array[@]}"; do echo "$item"; done]],
				[[
$array = %s

foreach ($item in $array) {
    Write-Output $item
}]]
			)
			:format(hook_choices)

		hook_choices =
			vim.split(vim.fn.system(cmd), platform.choose("\n", "\r\n"))

		if hook_choices[#hook_choices] == "" then
			table.remove(hook_choices)
		end
		table.insert(hook_choices, "{custom}")

		utils.create_floating_options_window(
			hook_choices,
			"zuzu///hooks",
			function(value)
				if value == "{custom}" then
					return (':bd! | lua require("zuzu").edit_hook("\\ndirect-set\\n%s")<CR>'):format(
						hook_name
					)
				end
				return (':bd! | lua require("zuzu").set_hook("%s", "%s")<CR>'):format(
					hook_name,
					value
				)
			end,
			function(idx)
				if idx == #hook_choices then
					return 0
				end
				return idx
			end
		)
		return
	end

	vim.ui.input({
		prompt = ('Enter new value for hook "%s": '):format(hook_name),
	}, function(input)
		if not input then
			return
		end
		print("\nUpdated hook to: " .. input)
		local hooks = Profile.hooks(profile)
		state.build_cache = {}
		hooks[hook_idx][2] = input
		Atlas.atlas_write(
			state.atlas,
			Preferences.get_atlas_path(state.preferences)
		)
	end)
end

---@param state State
---@param path string
---@param hook_name string
---@param hook_val string
M.state_set_hook = function(state, path, hook_name, hook_val)
	local profile = utils.assert(
		Atlas.resolve_profile(state.atlas, path),
		"No applicable build profile found."
	)

	for _, hook_pair in ipairs(Profile.hooks(profile)) do
		if hook_pair[1] == hook_name then
			hook_pair[2] = tostring(hook_val)
			state.build_cache = {}
			print("Updated hook to: " .. hook_val)
			Atlas.atlas_write(
				state.atlas,
				Preferences.get_atlas_path(state.preferences)
			)
			return
		end
	end

	utils.error(('Could not find hook "%s"'):format(hook_name))
end

return M
