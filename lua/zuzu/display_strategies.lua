local M = {}

M.command = function(cmd)
	vim.cmd("!" .. cmd)
end

---@param modifiers string
---@param buffer_mode boolean?
---@return DisplayStrategyFunc
M.split_terminal = function(modifiers, buffer_mode)
	if buffer_mode == nil then
		buffer_mode = false
	end
	---@type DisplayStrategyFunc
	---@return integer? buf_id
	return function(cmd, _, _, _, _, is_reopen)
		if is_reopen and buffer_mode then
			vim.cmd(("%s split | enew"):format(modifiers))
		else
			vim.cmd(modifiers .. " split")
			vim.cmd("set scrollback=100000")
			vim.cmd("terminal " .. cmd)
		end
		if buffer_mode then
			return vim.api.nvim_get_current_buf()
		end
	end
end

M.background = require("zuzu.background").display_strategy

return M
