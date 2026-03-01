---@param newline_delimeter string?
---@param log_level_highlight_map table<integer, string>?
return function(newline_delimeter, log_level_highlight_map)
	newline_delimeter = newline_delimeter or " / "
	log_level_highlight_map = log_level_highlight_map
		or {
			[vim.log.levels.ERROR] = "ZuzuDelete",
			[vim.log.levels.INFO] = "ZuzuInfo",
			[vim.log.levels.WARN] = "ZuzuWarn",
		}
	---@param msg string
	---@param level integer?
	return function(msg, level)
		local color = log_level_highlight_map[level] or nil
		vim.schedule(function()
			vim.api.nvim_echo({
				{
					msg:gsub("\n", newline_delimeter),
					color,
				},
			}, true, {})
		end)
		return 0
	end
end
