local Atlas = require("zuzu.atlas")
local M = {}

local SAFETY = 1024

M.SPLIT_HORIZONTALLY = 1
M.SPLIT_VERTICALLY = 1

M.replace = function(char1, char2) end

local options = {
	display_strategies = {
		-- M.strategies.command,
		-- M.strategies.split.right,
		-- M.strategies.split.below,
	},
	keybinds = {
		build = {
			{ "zu", "ZU", "zU", "Zu" },
			{ "zv", "ZV", "zV", "Zv" },
			{ "zs", "ZS", "zS", "Zs" },
		},
		add_config = "z+",
		modify_config = "z=",
		delete_config = "z-",
	},
	cache_path = vim.fn.stdpath("data") .. "/zuzu-cache.json",
}

_ = [[
Config resolution rules:
 1) Closest in terms of path
 2) Least amount of accepted filetypes
]]

---@type Atlas
local atlas = {
	[""] = {
		{ 5, { "lua" },  {}, "lua $file", { "lua $file\necho hi", "", "" } },
		{ 99, { "txt" }, {}, "cat $file", { "", "", "wc $file" } },
	},
	["/home"] = {
		{
			-1,
			{ "lua" },
			{},
			"",
			{
				"lua $file; echo specific",
				"lua $file\necho hi",
				"",
				"",
			},
		},
	},
}


local prof, txt = Atlas.resolve_profile(atlas, "/home/joe/foo/bar.lua")
print(vim.inspect(prof), txt)

M.setup = function() end

return M
