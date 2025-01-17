local utils = require("zuzu.utils")
local Profile = require("zuzu.profile")
local platform = require("zuzu.platform")
local ProfileMap = require("zuzu.profile_map")
local Atlas = require("zuzu.atlas")
local M = {}

---@class (exact) ProfileEditorState
---@field buf_id integer
---@field linked_profiles ProfileMap

---@class (exact) ProfileEditor
---@field state ProfileEditorState?
---@field build_keybinds string[]
---@field path string
---@field atlas Atlas
---@field atlas_path string

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
		if vim.api.nvim_buf_get_name(buf_id) == editor.path then
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end
	end
	editor.state = nil
end

---@param editor ProfileEditor
---@param root string
function M.new_profile_text(editor, root)
	local _, _, extension = utils.get_parent_directory_basename_extension(root)
	return string.format(
		[[
### {{ root: %s }}
### {{ filetypes: %s }}
### {{ depth: 0 }}
### {{ hooks }}
### {{ setup }}


### {{ %s }}
]],
		root,
		extension,
		table.concat(editor.build_keybinds, " }}\n\n\n### {{ ")
	)
end

---@param editor ProfileEditor
---@param roots string[]
function M.editor_open(editor, roots)
	M.editor_close(editor)
	local text = (function()
		if #roots == 1 then
			return M.new_profile_text(editor, roots[1])
		end
	end)()

	local buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf_id, "filetype", "bash")
	vim.api.nvim_buf_set_name(buf_id, editor.path)
	vim.api.nvim_buf_set_lines(buf_id, 0, 0, false, vim.split(text, "\n"))
	vim.api.nvim_set_current_buf(buf_id)
	vim.api.nvim_win_set_cursor(0, { 9, 0 })
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
	vim.api.nvim_command("startinsert")
	vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf_id })

	editor.state = {
		buf_id = buf_id,
		linked_profiles = {},
	}
	editor.state.linked_profiles = {}

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf_id,
		callback = function()
			if not vim.api.nvim_buf_is_valid(buf_id) then
				return
			end
			local profile_map = M.parse_editor_lines(
				editor,
				vim.api.nvim_buf_get_lines(buf_id, 0, -1, true)
			)
			local should_prompt_user = false
			---@type Action[]
			local actions = {}
			---@type Action
			local action
			for id, profile in pairs(profile_map) do
				local existing_profile = Atlas.find_by_id(editor.atlas, id)
				if existing_profile then
					local profile_is_linked = editor.state.linked_profiles[id]
						~= nil
					if not Profile.equals(profile, existing_profile) then
						action = {
							type = profile_is_linked and "replace"
								or "overwrite",
							id = id,
							profile = profile,
							other = existing_profile,
						}
						should_prompt_user = should_prompt_user
							or not profile_is_linked
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
					should_prompt_user = should_prompt_user or true
				end
			end
			local prompt = { { "Looks good?" } }
			for i = 1, #actions do
				action = actions[i]
				local root, filetypes, depth = ProfileMap.split_id(action.id)
				local type = action.type
				table.insert(prompt, {
					('\n    [ %s%s ] root = %s, filetypes = "%s", depth = %s'):format(
						(" "):rep(#"overwrite" - #type),
						type,
						root,
						filetypes,
						depth
					),
					("Zuzu%s%s"):format(
						type:sub(1, 1):upper(),
						type:sub(2, #type)
					),
				})
			end
			table.move({
				{ "\n\n" },
				{ "[Y]", "ZuzuHighlight" },
				{ "es  " },
				{ "[N]", "ZuzuHighlight" },
				{ "o  e" },
				{ "[X]", "ZuzuHighlight" },
				{ "it" },
			}, 1, 7, #prompt + 1, prompt)
			vim.api.nvim_echo(prompt, false, {})
			vim.api.nvim_set_option_value("modified", false, { buf = buf_id })
			vim.ui.input({ prompt = "" }, function(input)
				if string.lower(string.sub(input, 1, 1)) == "x" then
					vim.api.nvim_buf_delete(buf_id, {})
					return
				end
				if string.lower(string.sub(input, 1, 1)) == "y" then
					M.editor_apply_actions(editor, actions)
					local atlas_handle = assert(io.open(editor.atlas_path, "w"))
					assert(atlas_handle:write(vim.fn.json_encode(editor.atlas)))
					atlas_handle:close()
					local action_counts = {}
					for i = 1, #actions do
						action = actions[i]
						action_counts[action.type] = (
							action_counts[action.type] or 0
						) + 1
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
						table.concat(action_strings, "\n"),
						vim.log.levels.INFO
					)
					vim.api.nvim_buf_delete(buf_id, {})
					return
				end
			end)
		end,
	})
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
				error(
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
			error(errmsg)
		end
		return next_line, match
	end

	---@param start_line integer
	---@param end_line integer
	---@return string
	local concat_lines = function(start_line, end_line)
		return table.concat(
			lines,
			platform.choose("\n", "\r\n"),
			start_line,
			end_line
		)
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
			string.format("^### {{ %s }}$", editor.build_keybinds[1]),
			true
		)
		local setup = concat_lines(line, next_line - 1)
		line = next_line + 1

		local builds = {}
		for i = 2, #editor.build_keybinds do
			next_line = expect_header(
				line,
				string.format("^### {{ %s }}$", editor.build_keybinds[i]),
				true
			)
			builds[i - 1] = concat_lines(line, next_line - 1)
			line = next_line + 1
		end

		next_line, _ = seek_header(line, "^### {{ root: (.-) }}$", true)
		next_line = next_line or #lines + 1
		table.insert(builds, concat_lines(line, next_line - 1))
		line = next_line
		local profile, root_name =
			Profile.new(root, filetypes, depth, hooks, setup, builds)
		ProfileMap.map_insert(profiles, root_name, profile)
	end
	return profiles
end

---@param editor ProfileEditor
---@param actions Action[]
---@return ProfileEditor
function M.editor_apply_actions(editor, actions)
	for _, action in ipairs(actions) do
		local root = assert(ProfileMap.split_id(action.id))
		local switch_table = {
			---@param create_action CreateAction
			create = function(create_action)
				Atlas.insert(editor.atlas, root, create_action.profile)
			end,
			---@param replace_action ReplaceAction
			replace = function(replace_action)
				local profile =
					assert(Atlas.find_by_id(editor.atlas, replace_action.id))
				Profile.set(profile, replace_action.profile)
			end,
			---@param overwrite_action OverwriteAction
			overwrite = function(overwrite_action)
				local profile =
					assert(Atlas.find_by_id(editor.atlas, overwrite_action.id))
				Profile.set(profile, overwrite_action.profile)
			end,
			---@param delete_action DeleteAction
			delete = function(delete_action)
				assert(
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
