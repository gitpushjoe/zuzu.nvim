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
			.. platform.dispatch(function()
				return string.format("export %s='%s'\n", hook_name, hook_val)
			end, function()
				return string.format("$env:%s = '%s'\n", hook_name, hook_val)
			end)
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
	) .. (
		"function %s {\n:\n%s\n}\n%s 2>&1 | tee %s"):format(
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

return M
