local Atlas = require("zuzu.atlas")
local State = require("zuzu.state")
local platform = require("zuzu.platform")
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
	cache_path = vim.fn.stdpath("data")
		.. platform.PATH_SEP
		.. "zuzu-cache.json",
}

_ = [[
Config resolution rules:
 1) Closest in terms of path
 2) Least amount of accepted filetypes
]]

local name_hook = { "name", "joe" }

---@type Atlas
local atlas = {
	[""] = {
		{
			3,
			{ "lua" },
			{ name_hook },
			'echo "My name is $name"',
			{
				[[echo "Word count: "
wc $file
echo "Files in parent directory: "
ls -al -1 $parent
echo "Output: "
lua $file]],
				"",
				"",
			},
		},
		{ 99, { "txt" }, {}, "", { "date +%s%6N", "", "wc $file" } },
	},
	["/home"] = {
		{
			0,
			{ "lua" },
			{ { "foo", "bar" } },
			"echo 'Doing some setup'",
			{
				"|specific|lua $file\necho $foo\necho specific",
				"lua $file\necho hi",
				"",
				"",
			},
		},
	},
}

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
}

M.debug = function()
	local handle = assert(io.popen("date +%s%6N"))
	local start = handle:read("*a")
	handle:close()

	print(State.state_build(state, vim.fn.expand("%:p"), 1))

	handle = assert(io.popen("date +%s%6N"))
	local diff = tonumber(handle:read("*a")) - tonumber(start)
	handle:close()

	print(string.format("%s us %s", diff, start))
end

M.setup = function() end

return M
