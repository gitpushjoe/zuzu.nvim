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
	utils.assert(state)
	utils.assert(type(build_idx) == type(1))
	utils.assert(type(display_strategy_idx) == type(1))
	local cmd =
		utils.assert(State.state_build(state, validate_path(), build_idx))
	preferences.display_strategies[display_strategy_idx](cmd)
end

M.reopen = function(display_strategy_idx)
	preferences.display_strategies[display_strategy_idx](
		"cat " .. Preferences.get_last_path(preferences)
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

M.setup = function(table)
	if setup_called then
		vim.notify(
			"zuzu.nvim: setup cannont be called twice",
			vim.log.levels.WARN
		)
	end
	vim.cmd([[highlight ZuzuCreate guifg=LightGreen]])
	vim.cmd([[highlight ZuzuReplace guifg=Violet]])
	vim.cmd([[highlight ZuzuOverwrite guifg=LightMagenta]])
	vim.cmd([[highlight ZuzuDelete guifg=#ff3030]])
	vim.cmd([[highlight ZuzuHighlight guifg=Orange]])
	setup_called = true
	preferences = utils.assert(
		Preferences.new('require("zuzu.nvim").setup(...)', table or {})
	)
	Preferences.initialize(preferences)
	atlas = (function()
		local handle = io.open(Preferences.get_atlas_path(preferences), "r")
		if not handle then
			handle = utils.assert(
				io.open(Preferences.get_atlas_path(preferences), "w"),
				"Could not create file "
					.. Preferences.get_atlas_path(preferences)
			)
			handle:close()
			handle = utils.assert(
				io.open(Preferences.get_atlas_path(preferences), "r")
			)
		end
		local text = handle:read("*a")
		handle:close()
		_, table = pcall(function()
			return (text == "" or text == "[]") and {}
				or vim.fn.json_decode(text)
		end)
		return table or {}
	end)()
	state = {
		preferences = preferences,
		atlas = atlas,
		hooks = {},
		build_cache = {},
		hooks_is_dirty = true,
		core_hooks_is_dirty = true,
		profile_editor = {
			preferences = preferences,
			atlas = atlas,
		},
	}
	Preferences.bind_keybinds(preferences)
end

return M
