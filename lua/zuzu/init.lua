local Atlas = require("zuzu.atlas")
local Preferences = require("zuzu.preferences")
local State = require("zuzu.state")
local utils = require("zuzu.utils")
local M = {}

---@type State
local state
---@type Atlas
local atlas
---@type Preferences
local preferences

local setup_called = false

local validate_path = function()
	local path = vim.fn.expand("%:p")
	utils.assert(
		utils.get_parent_directory_basename_extension(path),
		"Operation not allowed. Current path is invalid."
	)
	return path
end

M.run = function(build_idx, display_strategy_idx)
	utils.assert(state, "setup() has failed or has not been called")
	utils.assert(type(build_idx) == type(1), "`build_idx` should be an integer")
	utils.assert(
		type(display_strategy_idx) == type(1),
		"`display_strategy_idx` should be an integer"
	)
	local cmd =
		utils.assert(State.state_build(state, validate_path(), build_idx))
	preferences.display_strategies[display_strategy_idx](
		cmd,
		utils.read_only(assert(state.profile)),
		build_idx,
		Preferences.get_last_stdout_path(preferences),
		Preferences.get_last_stderr_path(preferences)
	)
end

M.reopen = function(display_strategy_idx)
	preferences.display_strategies[display_strategy_idx](
		"cat "
			.. Preferences.get_last_stdout_path(preferences)
			.. " && echo -e '\\033[31m' && "
			.. "cat "
			.. Preferences.get_last_stderr_path(preferences)
			.. " && echo -n -e '\\033[0m'",
		utils.read_only(
			utils.assert(Atlas.resolve_profile(state.atlas, validate_path()))
		),
		0,
		Preferences.get_last_stdout_path(preferences),
		Preferences.get_last_stderr_path(preferences)
	)
end

M.new_profile = function()
	State.state_edit_new_profile(state, validate_path())
end

M.new_project_profile = function()
	State.state_edit_new_profile_at_directory(state, validate_path())
end

M.edit_profile = function()
	State.state_edit_most_applicable_profile(state, validate_path())
end

M.edit_all_applicable_profiles = function()
	State.state_edit_all_applicable_profiles(state, validate_path())
end

M.edit_all_profiles = function()
	State.state_edit_all_profiles(state)
end

---@param hook_name string
M.edit_hook = function(hook_name)
	State.state_edit_hook(state, validate_path(), hook_name)
end

M.edit_hooks = function()
	State.state_edit_hooks(state, validate_path())
end

---@param hook_name string
M.set_hook = function(hook_name, hook_val)
	State.state_set_hook(state, validate_path(), hook_name, hook_val)
end

M.version = function()
	print(require("zuzu.version"))
end

M.setup = function(table)
	if setup_called then
		vim.notify(
			"zuzu.nvim: setup cannont be called twice",
			vim.log.levels.WARN
		)
		return
	end
	vim.cmd([[highlight ZuzuCreate guifg=LightGreen]])
	vim.cmd([[highlight ZuzuReplace guifg=Violet]])
	vim.cmd([[highlight ZuzuOverwrite guifg=LightMagenta]])
	vim.cmd([[highlight ZuzuDelete guifg=#ff3030]])
	vim.cmd([[highlight ZuzuHighlight guifg=Orange]])
	vim.cmd([[highlight ZuzuBackgroundRun guifg=#888888]])
	vim.cmd([[highlight ZuzuSuccess guifg=LightGreen]])
	vim.cmd([[highlight ZuzuFailure guifg=LightRed]])
	setup_called = true
	preferences = utils.assert(
		Preferences.new('require("zuzu.nvim").setup(...)', table or {})
	)
	Preferences.initialize(preferences)
	atlas = Atlas.atlas_read(Preferences.get_atlas_path(preferences))
	state = {
		preferences = preferences,
		atlas = atlas,
		hooks = {},
		build_cache = {},
		profile_editor = {
			preferences = preferences,
			atlas = atlas,
			cache_clear = function()
				state.build_cache = {}
			end,
		},
	}
	Preferences.bind_keymaps(preferences)
end

return M
