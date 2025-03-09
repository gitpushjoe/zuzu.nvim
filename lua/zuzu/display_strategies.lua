local M = {}

M.command = function(cmd)
	vim.cmd("!" .. cmd)
end

---@param modifiers string
---@param terminal_mode_reopen boolean?
---@return DisplayStrategyFunc
M.split_terminal = function(modifiers, terminal_mode_reopen)
	if terminal_mode_reopen == nil then
		terminal_mode_reopen = false
	end
	---@type DisplayStrategyFunc
	---@return integer? buf_id
	return function(cmd, _, _, _, _, is_reopen)
		if (not terminal_mode_reopen) and is_reopen then
			vim.cmd(("%s split | enew"):format(modifiers))
			return vim.api.nvim_get_current_buf()
		end
		vim.cmd(modifiers .. " split")
		vim.cmd("set scrollback=100000")
		vim.cmd("terminal " .. cmd)
	end
end

M.background = require("zuzu.background").display_strategy

return M
