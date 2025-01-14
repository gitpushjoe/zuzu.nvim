local M = {}

M.SPLIT_HORIZONTALLY = 1
M.SPLIT_VERTICALLY = 1

M.replace = function(char1, char2) end

-- local options = {
-- 	display_strategies = {
-- 		M.strategies.command,
-- 		M.strategies.split.right,
-- 		M.strategies.split.below
-- 	},
-- 	keybinds = {
-- 		build = {
-- 			{ "zu", "ZU", "zU", "Zu" },
-- 			M.replace("u", "v"),
-- 			M.replace("u", "s"),
-- 		},
-- 	},
-- }

local options = {
	display_strategies = {
		M.strategies.command,
		M.strategies.split.right,
		M.strategies.split.below
	},
	keybinds = {
		build = {
			{ "zu", "ZU", "zU", "Zu" },
			{ "zv", "ZV", "zV", "Zv" },
			{ "zs", "ZS", "zS", "Zs" },
		},
	},
	cache_path = vim.fn.stdpath("data") .. "/zuzu-cache.json"
}

M.setup = function() end

return M
