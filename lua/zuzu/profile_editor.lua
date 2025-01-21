local utils = require("zuzu.utils")
local Profile = require("zuzu.profile")
local platform = require("zuzu.platform")
local ProfileMap = require("zuzu.profile_map")
local Atlas = require("zuzu.atlas")
local Preferences = require("zuzu.preferences")
local M = {}

---@class (exact) ProfileEditorState
---@field buf_id integer
---@field linked_profiles ProfileMap

---@class (exact) ProfileEditor
---@field state ProfileEditorState?
---@field preferences Preferences
---@field atlas Atlas
---@field cache_clear function

---@class (exact) CreateAction
---@field type "create"
---@field id string
---@field profile Profile

---@class (exact) ReplaceAction
---@field type "replace"
---@field id string
---@field profile Profile
---@field other Profile

---@class (exact) OverwriteAction
---@field type "overwrite"
---@field id string
---@field profile Profile
---@field other Profile

---@class (exact) DeleteAction
---@field type "delete"
---@field id string
---@field profile Profile

---@alias Action CreateAction|ReplaceAction|OverwriteAction|DeleteAction

---@param editor ProfileEditor
function M.editor_close(editor)
	for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf_id) == "zuzu///editor" then
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end
	end
	editor.state = nil
end

---@param editor ProfileEditor
---@param id string
---@param profile Profile
---@return string
function M.profile_text(editor, id, profile)
	local root, filetypes, depth = ProfileMap.split_id(id)
	local text = ([[
### {{ root: %s }}
### {{ filetypes: %s }}
### {{ depth: %s }}
### {{ hooks }}%s
### {{ setup }}
%s]]):format(
		root == "" and "*" or root,
		filetypes == "" and "*" or filetypes,
		depth == "inf" and "-1" or depth,
		(function()
			local hook_text = ""
			for _, hook_pair in ipairs(Profile.hooks(profile)) do
				local hook_name = hook_pair[1]
				local hook_val = hook_pair[2] or ""
				hook_val = utils.str_ends_with(
					hook_name,
					editor.preferences.hook_choices_suffix
				) and hook_val or string.find(hook_val, "%s") and ('"%s"'):format(
					hook_val
				) or hook_val
				hook_text = hook_text
					.. (platform.choose("\nexport %s=%s", "\r\n$%s=%s")):format(
						hook_name,
						hook_val
					)
			end
			return hook_text .. (hook_text ~= "" and platform.NEWLINE or "")
		end)(),
		Profile.setup(profile)
	)
	for i, keymap in ipairs(editor.preferences.keymaps.build[1]) do
		local build_text = Profile.build(profile, i)
		local name, rest = build_text:match("|(.+)|(.*)")
		if name then
			build_text = ("### {{ name: %s }}%s"):format(
				name,
				platform.NEWLINE .. rest
			)
		end
		text = text .. ([[

### {{ %s }}
%s]]):format(keymap, build_text)
	end
	return text
end

---@param editor ProfileEditor
---@param root string
function M.editor_open_new_profile(editor, root)
	local _, _, extension = utils.get_parent_directory_basename_extension(root)
	local profile = Profile.new(
		root,
		extension,
		"0",
		{},
		platform.NEWLINE,
		{},
		editor.preferences.hook_choices_suffix
	)
	local id = ProfileMap.get_id(root, profile)
	M.editor_open(editor, { [id] = profile })
end

---@param editor ProfileEditor
---@param root string
function M.editor_open_new_profile_at_directory(editor, root)
	local directory, _, extension =
		utils.get_parent_directory_basename_extension(root)
	local profile = Profile.new(
		directory,
		extension,
		"-1",
		{},
		platform.NEWLINE,
		{},
		editor.preferences.hook_choices_suffix
	)
	M.editor_open(editor, { [ProfileMap.get_id(directory, profile)] = profile })
end

---@param editor ProfileEditor
---@param profiles ProfileMap
---@param link_profiles boolean?
function M.editor_open(editor, profiles, link_profiles)
	link_profiles = link_profiles or false
	M.editor_close(editor)
	local text = (function()
		local res = ""
		for id, profile in pairs(profiles) do
			res = res
				.. (res ~= "" and platform.NEWLINE or "")
				.. M.profile_text(editor, id, profile)
		end
		return res
	end)()

	local lines = vim.split(text:gsub("\r", ""), "\n")
	local cursor_pos = (function()
		local header = ("### {{ %s }}"):format(
			editor.preferences.keymaps.build[1][1]
		)
		for i = #lines, 1, -1 do
			if lines[i] == header then
				return math.min(i + 1, #lines)
			end
		end
		return 1
	end)()

	local buf_id = vim.api.nvim_create_buf(false, true)
	editor.state = {
		linked_profiles = link_profiles and profiles or {},
		buf_id = buf_id,
	}
	vim.api.nvim_buf_set_option(buf_id, "filetype", "bash")
	vim.api.nvim_buf_set_name(buf_id, "zuzu///editor")
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
	vim.api.nvim_set_current_buf(buf_id)
	vim.api.nvim_win_set_cursor(0, { cursor_pos, 0 })
	vim.api.nvim_create_augroup("CloseBufferOnBufferClose", { clear = true })
	vim.api.nvim_create_autocmd("BufLeave", {
		group = "CloseBufferOnBufferClose",
		pattern = "*",
		callback = function()
			if vim.fn.bufnr("%") == buf_id then
				vim.cmd("b#|bwipeout! " .. buf_id)
			end
		end,
	})
	if not link_profiles then
		vim.api.nvim_command("startinsert")
	end
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf_id })
	vim.api.nvim_set_option_value("modified", false, { buf = buf_id })

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf_id,
		callback = function()
			vim.api.nvim_set_option_value("modified", false, { buf = buf_id })
			if not vim.api.nvim_buf_is_valid(buf_id) then
				return
			end
			local profile_map = M.parse_editor_lines(
				editor,
				vim.api.nvim_buf_get_lines(buf_id, 0, -1, true)
			)
			local actions, should_prompt_user =
				M.generate_actions(editor, profile_map)
			if #actions == 0 then
				vim.api.nvim_buf_delete(buf_id, {})
				return
			end
			local prompt = M.generate_prompt_from_actions(actions)
			vim.api.nvim_echo(prompt, false, {})
			local apply = function()
				M.apply_actions(editor, actions)
				vim.api.nvim_buf_delete(buf_id, {})
			end
			if not should_prompt_user then
				apply()
				return
			end
			vim.ui.input({ prompt = "" }, function(input)
				if string.lower(string.sub(input, 1, 1)) == "x" then
					vim.api.nvim_buf_delete(buf_id, {})
				elseif string.lower(string.sub(input, 1, 1)) == "y" then
					apply()
				end
			end)
		end,
	})
end

---@param editor ProfileEditor
---@param actions Action[]
function M.apply_actions(editor, actions)
	editor.cache_clear()
	M.editor_apply_actions(editor, actions)
	Atlas.atlas_write(
		editor.atlas,
		Preferences.get_atlas_path(editor.preferences)
	)
	local action_counts = {}
	for _, action in ipairs(actions) do
		action_counts[action.type] = (action_counts[action.type] or 0) + 1
	end
	local action_strings = {}
	for action_type, count in pairs(action_counts) do
		table.insert(
			action_strings,
			("%s build profile%s %s"):format(
				count,
				count > 1 and "s" or "",
				action_type == "overwrite" and "overwritten"
					or action_type .. "d"
			)
		)
	end
	vim.notify(
		table.concat(action_strings, platform.NEWLINE),
		vim.log.levels.INFO
	)
end

---@param editor ProfileEditor
---@param lines string[]
---@return ProfileMap
function M.parse_editor_lines(editor, lines)
	---@param line integer
	---@param pattern string
	---@param allow_name boolean?
	---@return integer? line
	---@return string? match
	---@return string? errmsg
	local seek_header = function(line, pattern, allow_name)
		allow_name = allow_name or false
		while lines[line] do
			local match = string.match(lines[line], pattern)
			if match then
				return line, match
			end
			if
				lines[line]:sub(1, #"### {{ ") == "### {{ "
				and not (
					allow_name
					and lines[line]:sub(#"### {{ name: ") ~= "### {{ name: "
				)
			then
				utils.error(
					string.format(
						'Unexpected header: "%s"\nWas searching for pattern: "%s"',
						lines[line],
						pattern
					)
				)
			end
			line = line + 1
		end
		return nil,
			nil,
			string.format('Failed to find a match for pattern: "%s"', pattern)
	end

	---@param line integer
	---@param pattern string
	---@param allow_name boolean?
	---@return integer line
	---@return string match
	local expect_header = function(line, pattern, allow_name)
		local next_line, match, errmsg = seek_header(line, pattern, allow_name)
		if not next_line or not match then
			utils.error(errmsg)
			error()
		end
		return next_line, match
	end

	---@param start_line integer
	---@param end_line integer
	---@return string
	local concat_lines = function(start_line, end_line)
		return table.concat(lines, platform.NEWLINE, start_line, end_line)
	end

	local profiles = ProfileMap.new()
	local line = 1
	while true do
		local next_line, root = seek_header(line, "^### {{ root: (.-) }}$")
		if not next_line or not root then
			break
		end
		line = next_line + 1

		local filetypes
		line, filetypes = expect_header(line, "^### {{ filetypes: (.-) }}$")
		line = line + 1

		local depth
		line, depth = expect_header(line, "^### {{ depth: (.-) }}$")
		line = line + 1

		line = expect_header(line, "^### {{ hooks }}$")
		next_line = expect_header(line + 1, "^### {{ setup }}$")
		local hooks = {}
		table.move(lines, line + 1, next_line - 1, 1, hooks)
		line = next_line + 1

		next_line = expect_header(
			line,
			string.format(
				"^### {{ %s }}$",
				editor.preferences.keymaps.build[1][1]
			),
			true
		)
		local setup = concat_lines(line, next_line - 1)
		line = next_line + 1

		local builds = {}
		for i = 2, #editor.preferences.keymaps.build[1] do
			next_line = expect_header(
				line,
				string.format(
					"^### {{ %s }}$",
					editor.preferences.keymaps.build[1][i]
				),
				true
			)
			builds[i - 1] = concat_lines(line, next_line - 1)
			line = next_line + 1
		end

		next_line, _ = seek_header(line, "^### {{ root: (.-) }}$", true)
		next_line = next_line or #lines + 1
		table.insert(builds, concat_lines(line, next_line - 1))
		line = next_line
		local profile, root_name = Profile.new(
			root,
			filetypes,
			depth,
			hooks,
			setup,
			builds,
			editor.preferences.hook_choices_suffix
		)
		ProfileMap.map_insert(profiles, root_name, profile)
	end
	return profiles
end

---@param editor ProfileEditor
---@param profile_map ProfileMap
---@return Action[] actions
---@return boolean should_prompt_user
function M.generate_actions(editor, profile_map)
	local should_prompt_user = false
	---@type Action[]
	local actions = {}
	---@type Action
	local action
	for id, profile in pairs(profile_map) do
		local existing_profile = Atlas.find_by_id(editor.atlas, id)
		if existing_profile then
			local profile_is_linked = editor.state.linked_profiles[id] ~= nil
			if not Profile.equals(profile, existing_profile) then
				action = {
					type = profile_is_linked and "replace" or "overwrite",
					id = id,
					profile = profile,
					other = existing_profile,
				}
				should_prompt_user = should_prompt_user
					or (
						editor.preferences.prompt_on_simple_edits
						and not profile_is_linked
					)
				table.insert(actions, action)
			end
		else
			---@type CreateAction
			action = { type = "create", id = id, profile = profile }
			table.insert(actions, action)
		end
	end
	for id, profile in pairs(editor.state.linked_profiles) do
		if not profile_map[id] then
			---@type DeleteAction
			action = { type = "delete", id = id, profile = profile }
			table.insert(actions, action)
			should_prompt_user = true
		end
	end
	return actions, should_prompt_user
end

---@param actions Action[]
---@return string[][]
function M.generate_prompt_from_actions(actions)
	local prompt = { { "Looks good?" } }
	for _, action in ipairs(actions) do
		local root, filetypes, depth = ProfileMap.split_id(action.id)
		local type = action.type
		table.insert(prompt, {
			('\n    [ %s%s ] root = %s, filetypes = "%s", depth = %s'):format(
				(" "):rep(#"overwrite" - #type),
				type,
				root == "" and "/" or root,
				filetypes,
				depth
			),
			("Zuzu%s%s"):format(type:sub(1, 1):upper(), type:sub(2, #type)),
		})
	end
	table.move({
		{ "\n\n" },
		{ "[Y]", "ZuzuHighlight" },
		{ "es  " },
		{ "[N]", "ZuzuHighlight" },
		{ "o  e" },
		{ "[X]", "ZuzuDelete" },
		{ "it" },
	}, 1, 7, #prompt + 1, prompt)
	return prompt
end

---@param editor ProfileEditor
---@param actions Action[]
---@return ProfileEditor
function M.editor_apply_actions(editor, actions)
	for _, action in ipairs(actions) do
		local root = utils.assert(ProfileMap.split_id(action.id))
		local switch_table = {
			---@param create_action CreateAction
			create = function(create_action)
				Atlas.insert(editor.atlas, root, create_action.profile)
			end,
			---@param replace_action ReplaceAction
			replace = function(replace_action)
				local profile = utils.assert(
					Atlas.find_by_id(editor.atlas, replace_action.id)
				)
				Profile.set(profile, replace_action.profile)
			end,
			---@param overwrite_action OverwriteAction
			overwrite = function(overwrite_action)
				local profile = utils.assert(
					Atlas.find_by_id(editor.atlas, overwrite_action.id)
				)
				Profile.set(profile, overwrite_action.profile)
			end,
			---@param delete_action DeleteAction
			delete = function(delete_action)
				utils.assert(
					Atlas.delete(editor.atlas, root, delete_action.profile),
					"Unable to delete profile"
				)
			end,
		}
		switch_table[action.type](action)
	end
	return editor
end

return M
