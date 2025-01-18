local State = require("zuzu.state")
local platform = require("zuzu.platform")
local M = {}

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
		new_profile = "z+",
		new_project_profile = "z^",
		delete_profile = "z-",
		modify_profile = "z=",
		modify_all_applicable_profiles = "z*",
	},
	cache_path = platform.join_path(
		tostring(vim.fn.stdpath("data")),
		"zuzu-cache.json"
	),
}

-- local name_hook = { "name", "joe" }

-- ---@type Atlas
-- local atlas = {
-- 	[""] = {
-- 		{
-- 			{ "lua" },
-- 			3,
-- 			{ name_hook },
-- 			'echo "My name is $name"',
-- 			{
-- 				[[echo "Word count: "
-- wc $file
-- echo "Files in parent directory: "
-- ls -al -1 $parent
-- echo "Output: "
-- lua $file]],
-- 				"",
-- 				"",
-- 			},
-- 		},
-- 		{ { "txt" }, 99, {}, "", { "date +%s%6N", "", "wc $file" } },
-- 	},
-- 	["/home"] = {
-- 		{
-- 			{ "lua" },
-- 			0,
-- 			{ { "foo", "bar" } },
-- 			"echo 'Doing some setup'",
-- 			{
-- 				"|specific|lua $file\necho $foo\necho specific",
-- 				"lua $file\necho hi",
-- 				"",
-- 				"",
-- 			},
-- 		},
-- 	},
-- }

local atlas_path = vim.fn.expand("~/.zuzu/atlas.json")

local atlas = (function()
	local handle = assert(io.open(atlas_path, "r"))
	local text = handle:read("*a")
	handle:close()
	local _, table = pcall(function()
		return (text == "" or text == "[]") and {} or vim.fn.json_decode(text)
	end)
	return table or {}
end)()

---@type State
local state = {
	zuzu_path = vim.fn.expand("~/.zuzu"),
	atlas = atlas,
	hooks = {},
	build_cache = {},
	hooks_is_dirty = true,
	setup_is_dirty = true,
	core_hooks_is_dirty = true,
	core_hook_callbacks = State.DEFAULT_CORE_HOOK_CALLBACKS(),
	profile_editor = {
		build_keybinds = options.keybinds.build[1],
		path = "zuzu///profile_editor",
		atlas = atlas,
		atlas_path = atlas_path,
	},
}

vim.api.nvim_set_keymap(
	"n",
	"zd",
	'<cmd>lua require("zuzu").debug1()<CR>',
	{ noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
	"n",
	"z2",
	'<cmd>lua require("zuzu").debug2()<CR>',
	{ noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
	"n",
	"z=",
	'<cmd>lua require("zuzu").debug3()<CR>',
	{ noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
	"n",
	"z*",
	'<cmd>lua require("zuzu").debug4()<CR>',
	{ noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
	"n",
	"z?",
	'<cmd>lua require("zuzu").debug5()<CR>',
	{ noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
	"n",
	"z/",
	'<cmd>lua require("zuzu").debug6()<CR>',
	{ noremap = true, silent = true }
)

M.debug1 = function()
	State.state_edit_new_profile(state, vim.fn.expand("%:p"))
end

M.debug2 = function()
	-- local handle = assert(io.popen("date +%s%6N"))
	-- local start = handle:read("*a")
	-- handle:close()

	State.state_build(state, vim.fn.expand("%:p"), 1)

	-- handle = assert(io.popen("date +%s%6N"))
	-- local diff = tonumber(handle:read("*a")) - tonumber(start)
	-- handle:close()
	--
	-- print(string.format("%s us %s", diff, start))
end

M.debug3 = function()
	State.state_edit_most_applicable_profile(state, vim.fn.expand("%:p"))
end

M.debug4 = function()
	State.state_edit_all_profiles(state)
end

M.debug5 = function()
	State.state_edit_all_applicable_profiles(state, vim.fn.expand("%:p"))
end

M.debug6 = function()
	State.state_edit_new_profile_at_directory(state, vim.fn.expand("%:p"))
end

M.setup = function()
	vim.cmd([[highlight ZuzuCreate guifg=LightGreen]])
	vim.cmd([[highlight ZuzuReplace guifg=Violet]])
	vim.cmd([[highlight ZuzuOverwrite guifg=LightMagenta]])
	vim.cmd([[highlight ZuzuDelete guifg=#ff3030]])
	vim.cmd([[highlight ZuzuHighlight guifg=Orange]])
end

return M
