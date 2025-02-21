local Platform = require("zuzu.platform")
local Profile = require("zuzu.profile")

local M = {}

---@class MessageType: string
M.message_types = {
	SUCCESS = "SUCCESS",
	FAILURE = "FAILURE",
	UPDATE = "UPDATE",
	NORMAL = "NORMAL",
}

---@type integer?
local notify_id

M.print_functions = {

	---@param text string
	---@param message_type MessageType
	nvim_echo = function(text, message_type)
		local chunk = {
			text,
			({
				[M.message_types.SUCCESS] = "ZuzuSuccess",
				[M.message_types.FAILURE] = "ZuzuFailure",
				[M.message_types.UPDATE] = "ZuzuBackgroundRun",
				[M.message_types.NORMAL] = "Normal",
			})[message_type],
		}
		vim.api.nvim_echo(
			{ chunk },
			(
				message_type == M.message_types.SUCCESS
				or message_type == M.message_types.FAILURE
			),
			{}
		)
	end,

	---@param text string
	---@param message_type MessageType
	---@param is_initial_message boolean
	notify = function(text, message_type, is_initial_message)
		if is_initial_message then
			notify_id = nil
		end
		local id = vim.notify(
			text:gsub("zuzu: ", ""),
			({
				[M.message_types.FAILURE] = vim.log.levels.ERROR,
				[M.message_types.UPDATE] = vim.log.levels.INFO,
				[M.message_types.NORMAL] = vim.log.levels.OFF,
			})[message_type],
			{
				title = "zuzu",
				replace = notify_id,
			}
		)
		notify_id = id
	end,
}

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

---@param is_success boolean
M.open_qflist_if_errors = function(is_success)
	if not is_success then
		require("zuzu").qflist_prev_or_next(true)
	end
end

---@param loop_delay_ms number?
---@param print_func fun(text: string, message_type: MessageType, is_intiial_message: boolean?): any
---@param on_finish fun(is_success: boolean): any
M.display_strategy = function(loop_delay_ms, print_func, on_finish)
	print_func = print_func or M.print_functions.notify
	loop_delay_ms = loop_delay_ms or (1000 / 8)
	on_finish = on_finish or function() end

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

		print_func(
			string.format(
				" %s zuzu: Running %s",
				spinner[spinner_index],
				build_name
			),
			M.message_types.UPDATE,
			true
		)

		loop_timer_handle = vim.fn.timer_start(loop_delay_ms, function()
			local elapsed = get_time_ms() - start_time_ms - 10
			print_func(
				string.format(
					" %s zuzu: Running %s (elapsed: %.2fs)",
					spinner[spinner_index],
					build_name,
					elapsed / 1000
				),
				M.message_types.UPDATE
			)
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
					print_func(
						string.format(
							"%s finished in %.2f seconds",
							build_name,
							elapsed / 1000
						),
						M.message_types.NORMAL
					)
					on_finish(true)
					return
				end

				local handle =
					io.open(Platform.choose(last_stderr_path, last_stdout_path))
				local text = handle and handle:read("*a") or ""
				local success = #text == 0
				if handle then
					handle:close()
				end
				print_func(
					(" %s zuzu: %s finished in %.2f seconds%s"):format(
						success and "✓" or "☓",
						build_name,
						elapsed / 1000,
						success and "" or " with errors"
					),
					success and M.message_types.SUCCESS
						or M.message_types.FAILURE
				)
				on_finish(success)
			end,
		})

		vim.api.nvim_set_current_buf(original_buf)
	end
	return tbl.background_func
end

return M
