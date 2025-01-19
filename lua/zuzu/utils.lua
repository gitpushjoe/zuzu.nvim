local platform = require("zuzu.platform")

local M = {}

M.get_parent_directory_basename_extension = function(path)
	return path:match("(.*)" .. platform.PATH_SEP .. "(.*)%.(%w*)")
end

---@param err string?
M.error = function(err)
	vim.notify("zuzu: " .. (err or ""), vim.log.levels.ERROR)
	error(nil, 0)
end

---@generic T
---@param expr T?
---@param errmsg string?
---@return T
M.assert = function(expr, errmsg)
	if not expr then
		M.error(errmsg)
	end
	return expr
end

---@param str string
---@param prefix string
---@return boolean
M.str_starts_with = function(str, prefix)
	return string.sub(str, 1, #prefix) == prefix
end

---@param str string
---@param suffix string
---@return boolean
M.str_ends_with = function(str, suffix)
	return suffix == "" or string.sub(str, -#suffix) == suffix
end

---@param choices string[]
---@param buf_name string
---@param on_select fun(s: string): string
---@param modify_index (fun(i: integer): integer)|nil
M.create_floating_options_window = function(
	choices,
	buf_name,
	on_select,
	modify_index
)
	if not modify_index then
		modify_index = function(i)
			return i
		end
	end

	if #choices == 0 then
		return
	end

	local buf_id = vim.api.nvim_create_buf(false, true)
	local width = 30
	local height = math.min(15, #choices)
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2 - 1,
		style = "minimal",
		border = "rounded",
		title = "Press a key",
		title_pos = "center",
	}

	vim.api.nvim_buf_set_name(buf_id, buf_name)
	vim.api.nvim_open_win(buf_id, true, opts)

	vim.api.nvim_command("hi noCursor blend=100 cterm=strikethrough")
	vim.api.nvim_command("set guicursor+=a:noCursor/lCursor")

	local lines = {}
	for i, choice in ipairs(choices) do
		local idx = modify_index(i)
		table.insert(lines, (" %x -> %s"):format(idx, choice))
		vim.api.nvim_buf_set_keymap(
			buf_id,
			"n",
			("%x"):format(idx),
			on_select(choices[i]),
			{ noremap = true, silent = true }
		)
		if i == 15 then
			break
		end
	end
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

	vim.api.nvim_create_augroup("CloseBufferOnBufferClose", { clear = true })
	vim.api.nvim_create_autocmd("BufLeave", {
		group = "CloseBufferOnBufferClose",
		pattern = "*",
		callback = function()
			if vim.fn.bufnr("%") == buf_id then
				vim.cmd("b#|bwipeout! " .. buf_id)
			end
			vim.api.nvim_command("set guicursor-=a:noCursor/lCursor")
		end,
	})

	vim.api.nvim_set_current_buf(buf_id)
	for _, key in ipairs({ "<Esc>", "<Space>", "<CR>" }) do
		vim.api.nvim_buf_set_keymap(
			buf_id,
			"n",
			key,
			":bd!<CR>",
			{ noremap = true, silent = true }
		)
	end
	vim.api.nvim_set_option_value("modified", false, { buf = buf_id })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf_id })
	vim.cmd("setlocal nowrap")
end

return M
