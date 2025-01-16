local Profile = require("zuzu.profile")
local M = {}

---@class (exact) BuildPair
---@field [1] Profile profile
---@field [2] integer build index

---@class (exact) HookCallback
---@field [1] string name
---@field [2] fun(...): string callback

---@class (exact) HookPair
---@field [1] string name
---@field [2] string callback

---@class (exact) State
---@field hooks {[1]: string, [2]: string}[]
---@field profile Profile?
---@field build_cache table<string, BuildPair>
---@field setup_is_dirty boolean
---@field hooks_is_dirty boolean
---@field core_hooks_is_dirty boolean
---@field core_hook_callbacks HookCallback[]

---@return HookCallback[]
function M.DEFAULT_CORE_HOOK_CALLBACKS()
	return {
		{
			"file",
			function()
				return vim.fn.expand("%:p")
			end,
		},
		{
			"dir",
			function()
				return vim.fn.expand("%:p:h")
			end,
		},
		{
			"parent",
			function()
				return vim.fn.expand("%:p:h:h")
			end,
		},
	}
end

---@param state State
function M.state_resolve_hooks(state)
	local new_hooks = {}
	-- invariants:
	-- # of core hooks does not change
	-- core hook callbacks do not change
	-- core hooks are always at the beginning of state.hooks
	for i, hook_pair in ipairs(state.core_hook_callbacks) do
		local hook_name = hook_pair[1]
		local hook_func = hook_pair[2]
		local hook_val = hook_func()
		table.insert(new_hooks, { hook_name, hook_val })
		state.core_hooks_is_dirty = state.core_hooks_is_dirty
			or hook_val ~= state.hooks[i]
	end
	local hooks = Profile.hooks(state.profile)
	table.move(hooks, 1, #hooks, #new_hooks + 1, new_hooks)
	state.hooks = hooks
end

return M
