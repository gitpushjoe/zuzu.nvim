local Profile = require("zuzu.profile")
local Atlas = require("zuzu.atlas")
local platform = require("zuzu.platform")
local ProfileEditor = require("zuzu.profile_editor")
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
---@field zuzu_path string
---@field atlas Atlas
---@field hooks HookPair[]
---@field profile Profile?
---@field build_cache table<string, BuildPair>
---@field hooks_is_dirty boolean
---@field setup_is_dirty boolean
---@field core_hooks_is_dirty boolean
---@field core_hook_callbacks HookCallback[]
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
---@vararg string
---@return string
function M.join_path(state, ...)
	return platform.join_path(state.zuzu_path, ...)
end

---@param state State
---@return string
function M.get_hooks_path(state)
	return M.join_path(state, "hooks." .. platform.EXTENSION)
end

---@param state State
---@return string
function M.get_setup_path(state)
	return M.join_path(state, "setup." .. platform.EXTENSION)
end

---@param state State
---@return string
function M.get_builds_path(state)
	return M.join_path(state, "builds")
end

---@param state State
---@param name string
---@return string
function M.get_build_path(state, name)
	return M.join_path(state, "builds", name .. "." .. platform.EXTENSION)
end

---@param state State
---@return string
function M.get_editor_path(state)
	return M.join_path(state, "profile_editor")
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

	local hooks_handle = assert(io.open(M.get_hooks_path(state), "w+"))
	assert(hooks_handle:write(text))
	hooks_handle:close()

	return text
end

---@param state State
function M.state_write_setup(state)
	local setup_handle = assert(io.open(M.get_setup_path(state), "w+"))
	assert(setup_handle:write(Profile.setup(state.profile)))
	setup_handle:close()
end

---@param state State
---@param name string
---@param text string
---@param build_idx integer
function M.state_write_build(state, name, text, build_idx)
	text = string.format(
		platform.choose("source %s\nsource %s\n", '. "%s"\n. "%s"\n'),
		M.get_hooks_path(state),
		M.get_setup_path(state)
	) .. string.format(
		"function zuzu_cmd {\n%s\n}\nzuzu_cmd 2>&1 | tee ~/.zuzu/last.txt",
		text
	)
	local build_handle = assert(io.open(M.get_build_path(state, name), "w+"))
	assert(build_handle:write(text))
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
	for i, hook_pair in ipairs(state.core_hook_callbacks) do
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
	-- print(state.hooks_is_dirty)
	state.hooks = new_hooks
end

---@param state State
---@param path string
---@param build_idx integer
---@return string? errmsg
function M.state_build(state, path, build_idx)
	local profile = Atlas.resolve_profile(state.atlas, path)
	if not profile then
		error("No applicable build profile found.")
	end
	state.profile = profile
	M.state_resolve_hooks(state)
	if state.hooks_is_dirty then
		print(M.state_write_hooks(state))
		state.hooks_is_dirty = false
	end
	if state.setup_is_dirty then
		print(M.state_write_setup(state))
		state.setup_is_dirty = false
	end
	local build_name, build_text = Profile.build_info(profile, build_idx)
	local build = state.build_cache[build_name]
	local build_file_is_dirty = not (
		build
		and build[1] == profile
		and build[2] == build_idx
	)
	if build_file_is_dirty then
		print(M.state_write_build(state, build_name, build_text, build_idx))
	end
	vim.cmd(
		"!source "
			.. vim.fn.expand(
				platform.join_path(
					state.zuzu_path,
					"builds",
					build_name .. "." .. platform.EXTENSION
				)
			)
	)
end

---@param state State
---@param roots string[]
function M.state_edit_profiles(state, roots)
	ProfileEditor.editor_open(state.profile_editor, roots)
end

return M
