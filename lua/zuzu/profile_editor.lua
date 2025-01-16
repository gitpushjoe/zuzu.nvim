local utils = require("lua.zuzu.utils")
local M = {}

---@class (exact) ProfileEditorState
---@field buf_id integer
---@field referenced_roots string[]

---@class (exact) ProfileEditor
---@field state ProfileEditorState?
---@field build_keybinds string[]
---@field path string
---@field atlas Atlas

---@param editor ProfileEditor
function M.editor_close(editor)
	if not editor.state then
		return
	end
	for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
		if buf_id == editor.state.buf_id then
			vim.api.nvim_buf_delete(editor.state.buf_id, { force = true })
		end
	end
	os.remove(editor.path)
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
	vim.api.nvim_buf_set_option(buf_id, 'filetype', 'bash')
	vim.api.nvim_buf_set_name(buf_id, editor.path)
	vim.api.nvim_buf_set_lines(buf_id, 0, 0, false, vim.split(text, "\n"))
	vim.api.nvim_set_current_buf(buf_id)
	vim.api.nvim_win_set_cursor(0, {8, 0})
	vim.api.nvim_create_augroup(
		"CloseBufferOnBufferClose",
		{ clear = true }
	)
	vim.api.nvim_create_autocmd("BufLeave", {
		group = "CloseBufferOnBufferClose",
		pattern = "*",
		callback = function()
			if vim.fn.bufnr("%") == buf_id then
				vim.cmd("b#|bwipeout! " .. buf_id)
			end
		end,
	})
	vim.api.nvim_command('startinsert')

	editor.state = {
		buf_id = buf_id,
		referenced_roots = {},
	}
	editor.state.referenced_roots = {}
	table.move(roots, 1, #roots, 1, editor.state.referenced_roots)
end

return M
