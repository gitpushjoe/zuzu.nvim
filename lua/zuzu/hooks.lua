local M = {}

M.file = function()
	return vim.fn.expand("%:p")
end

M.directory = function()
	return vim.fn.expand("%:p:h")
end

M.parent_directory = function()
	return vim.fn.expand("%:p:h:h")
end

M.base = function()
	return vim.fn.fnamemodify(vim.fn.expand("%:t"), ":r")
end

M.filename = function()
	return vim.fn.expand("%:t")
end

return M
