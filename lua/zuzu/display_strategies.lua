local Profile = require("zuzu.profile")
local utils = require("zuzu.utils")
local Platform = require("zuzu.platform")
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
		vim.cmd(("%s split | terminal %s"):format(modifiers, cmd))
	end
end

---@type integer
local terminal_buf_id, start_time_ms
---@type uv_handle_t?
local loop_timer_handle
local spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

local get_time_ms = function()
	return tonumber(
		(
			vim.fn.system(
				require("zuzu.platform").choose(
					"perl -MTime::HiRes=gettimeofday -E 'my ($s, $us) = gettimeofday(); say $s * 1000 + int($us / 1000);'",
					"[math]::floor((Get-Date).ToUniversalTime().Ticks / 10000)"
				)
			)
		)
	)
end

---@param loop_delay_ms number?
M.background = function(loop_delay_ms)
	loop_delay_ms = loop_delay_ms or (1000 / 8)
	local tbl = {} --- for recursion
	---@type fun(cmd: string, profile: Profile, build_idx: integer, last_stdout_path: string, last_stderr_path: string, is_reopen?: boolean, safety_retry_count: number): integer?
	tbl.background_func = function(
		command,
		profile,
		build_idx,
		last_stdout_path,
		last_stderr_path,
		is_reopen,
		safety_retry_count
	)
		safety_retry_count = safety_retry_count or 0
		if terminal_buf_id and vim.api.nvim_buf_is_valid(terminal_buf_id) then
			vim.api.nvim_buf_delete(terminal_buf_id, { force = true })
		end
		if loop_timer_handle then
			if safety_retry_count > 16 then
				return
			end
			vim.schedule(function()
				tbl.background_func(
					command,
					profile,
					build_idx,
					last_stdout_path,
					last_stderr_path,
					is_reopen,
					safety_retry_count + 1
				)
			end)
			return
		end

		local original_buf = vim.api.nvim_get_current_buf()
		vim.cmd("enew")
		terminal_buf_id = vim.api.nvim_get_current_buf()

		start_time_ms = get_time_ms()
		local spinner_index = 1

		if loop_timer_handle then
			vim.fn.timer_stop(loop_timer_handle)
		end

		local build_name = Profile.build_info(profile, build_idx)
		if build_name == tostring(build_idx) then
			build_name = "build #" .. build_name
		end

		vim.api.nvim_echo({
			{
				string.format(
					" %s zuzu: Running %s",
					spinner[spinner_index],
					build_name
				),
				"ZuzuBackgroundRun",
			},
		}, false, {})

		loop_timer_handle = vim.fn.timer_start(loop_delay_ms, function()
			local elapsed = get_time_ms() - start_time_ms - 10
			vim.api.nvim_echo({
				{
					string.format(
						" %s zuzu: Running %s (elapsed: %.2fs)",
						spinner[spinner_index],
						build_name,
						elapsed / 1000
					),
					"ZuzuBackgroundRun",
				},
			}, false, {})
			spinner_index = spinner_index + 1
			if spinner_index > #spinner then
				spinner_index = 1
			end
		end, { ["repeat"] = -1 })

		vim.fn.termopen(command, {
			on_exit = function()
				if not loop_timer_handle then
					return
				end
				vim.fn.timer_stop(loop_timer_handle)
				loop_timer_handle = nil
				local elapsed = get_time_ms() - start_time_ms

				if Platform.PLATFORM == "win" then
					print(
						string.format(
							"%s finished in %.2f seconds",
							build_name,
							elapsed / 1000
						)
					)
					return
				end

				local handle =
					io.open(Platform.choose(last_stderr_path, last_stdout_path))
				local text = handle and handle:read("*a") or ""
				local success = #text == 0
				if handle then
					handle:close()
				end
				vim.api.nvim_echo({
					{
						(" %s zuzu: %s finished in %.2f seconds%s"):format(
							success and "✓" or "☓",
							build_name,
							elapsed / 1000,
							success and "" or " with errors"
						),
						success and "ZuzuSuccess" or "ZuzuFailure",
					},
				}, true, {})
			end,
		})

		vim.api.nvim_set_current_buf(original_buf)
	end
	return tbl.background_func
end

return M
