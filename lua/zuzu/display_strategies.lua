local M = {}

M.command = function(cmd)
	vim.cmd("!" .. cmd)
end

M.split_right = function(cmd)
	vim.cmd("vertical rightbelow split | terminal " .. cmd)
end

M.split_below = function(cmd)
	vim.cmd("horizontal rightbelow split | terminal " .. cmd)
end

return M
