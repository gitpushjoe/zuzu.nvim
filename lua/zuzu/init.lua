local Atlas = require("zuzu.atlas")
local Preferences = require("zuzu.preferences")
local State = require("zuzu.state")
local utils = require("zuzu.utils")
local colors = require("zuzu.colors")
local platform = require("zuzu.platform")
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
	if
		preferences.write_on_run
		and vim.api.nvim_buf_get_option(0, "modified")
	then
		vim.cmd("write")
	end
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
	local last_stdout_path = Preferences.get_last_stdout_path(preferences)
	local last_stderr_path = Preferences.get_last_stderr_path(preferences)
	local reopen_buf_id = preferences.display_strategies[display_strategy_idx](
		("%s%scat %s"):format(
			preferences.newline_before_reopen and "echo;" or "",
			preferences.reflect
					and preferences.reopen_reflect
					and (platform.choose(
						("[ -t 1 ]&&echo -en '%s';cat %s;[ -t 1 ]&&echo -en '\\033[0m';"):format(
							preferences.colors.reflect,
							Preferences.get_reflect_path(preferences)
						),
						("gc %s | %% { Write-Host $_ -f %s }"):format(
							Preferences.get_reflect_path(preferences),
							preferences.colors.reflect
						)
					) .. (preferences.newline_after_reflect and "echo '';" or ""))
				or "",
			Preferences.get_last_stdout_path(preferences)
		)
			.. (
				platform.PLATFORM ~= "win"
					and (";[ -t 1 ]&&echo -en '\\033[31m';cat %s;[ -t 1 ]&&echo -en '\\033[0m'||true"):format(
						Preferences.get_last_stderr_path(preferences)
					)
				or ""
			),
		utils.read_only(
			utils.assert(Atlas.resolve_profile(state.atlas, validate_path()))
		),
		0,
		last_stdout_path,
		last_stderr_path,
		true
	)
	if not reopen_buf_id then
		return
	end

	---@param str string
	---@return string[]
	local split_lines = function(str)
		local lines = {}
		for line in str:gmatch("([^\n]*)\n?") do
			table.insert(lines, line)
		end
		return lines
	end

	--- TODO: handle windows

	local line_number = 0
	if preferences.reflect and preferences.reopen_reflect then
		local reflect_lines = split_lines(
			(preferences.newline_before_reopen and platform.NEWLINE or "")
				.. (utils.read_from_path(
					Preferences.get_reflect_path(preferences) or ""
				) or "")
				.. (
					preferences.newline_after_reflect and platform.NEWLINE
					or ""
				)
		)
		vim.cmd(
			([[highlight ZuzuReopenReflect guifg=%s]]):format(
				colors.unix2ps(preferences.colors.reflect)
			)
		)
		for i, line in ipairs(reflect_lines) do
			vim.api.nvim_buf_set_lines(
				reopen_buf_id,
				i - 1,
				-1,
				false,
				{ line }
			)
			vim.api.nvim_buf_add_highlight(
				reopen_buf_id,
				-1,
				"ZuzuReopenReflect",
				i - 1,
				0,
				-1
			)
		end
		line_number = #reflect_lines - 1
	end

	local stdout_lines = split_lines(
		(
			(
					preferences.newline_before_reopen
					and not preferences.reopen_reflect
				)
				and platform.NEWLINE
			or ""
		) .. (utils.read_from_path(last_stdout_path) or "")
	)

	if stdout_lines[#stdout_lines] == "" then
		stdout_lines[#stdout_lines] = nil
	end

	vim.api.nvim_buf_set_lines(
		reopen_buf_id,
		line_number,
		-1,
		false,
		stdout_lines
	)
	if preferences.enter_closes_reopen_buffer then
		vim.api.nvim_buf_set_keymap(
			reopen_buf_id,
			"n",
			"<Enter>",
			":bd!<CR>",
			{ noremap = true, silent = true }
		)
	end

	local stderr_text = utils.read_from_path(last_stderr_path) or ""
	if stderr_text ~= "" then
		local stderr_lines = split_lines(stderr_text)
		local line_count = vim.api.nvim_buf_line_count(reopen_buf_id)

		vim.cmd(
			([[highlight ZuzuReopenStderr guifg=%s]]):format(
				colors.unix2ps(preferences.colors.reopen_stderr)
			)
		)
		for i, line in ipairs(stderr_lines) do
			vim.api.nvim_buf_set_lines(reopen_buf_id, -1, -1, false, { line })
			vim.api.nvim_buf_add_highlight(
				reopen_buf_id,
				-1,
				"ZuzuReopenStderr",
				line_count + i - 1,
				0,
				-1
			)
		end
	end

	local line_count = vim.api.nvim_buf_line_count(reopen_buf_id)
	if
		vim.api.nvim_buf_get_lines(
			reopen_buf_id,
			line_count - 1,
			line_count,
			false
		)[1] == ""
	then
		vim.api.nvim_buf_set_lines(
			reopen_buf_id,
			line_count - 1,
			line_count,
			false,
			{}
		)
	end

	vim.bo.readonly = true
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = reopen_buf_id })
	vim.api.nvim_set_option_value("modified", false, { buf = reopen_buf_id })
	vim.api.nvim_set_option_value("modifiable", false, { buf = reopen_buf_id })
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
	State.state_edit_all_profiles(state, validate_path())
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

---@param is_stable boolean?
M.toggle_qflist = function(is_stable)
	State.toggle_qflist(state, is_stable or false)
end

---@param is_next boolean
M.qflist_prev_or_next = function(is_next)
	State.qflist_prev_or_next(state, is_next)
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
			write_atlas_function = function() end,
		},
		qflist_open = false,
		error_namespace = vim.api.nvim_create_namespace("zuzu-errors"),
	}
	state.profile_editor.write_atlas_function =
		State.state_write_atlas_function(state)
	Preferences.bind_keymaps(preferences)
end

return M
