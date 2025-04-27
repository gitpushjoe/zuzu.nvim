local platform = require("zuzu.platform")

local M = {}

M.get_parent_directory_basename_extension = function(path)
	return path:match("(.*)" .. platform.PATH_SEP .. "(.*)%.(%w*)")
end

---@param err string?
M.error = function(err)
	vim.notify("zuzu: " .. (err or ""), vim.log.levels.ERROR)
	vim.schedule(function()
		print(" ")
	end)
	error(nil, 0)
end

---@generic T
---@param expr T?
---@param errmsg string?
---@return T
M.assert = function(expr, errmsg)
	if not expr then
		M.error(errmsg)
	end
	return expr
end

---@param tbl table
---@return table
M.reverse_table = function(tbl)
	local new_tbl = {}
	for _, item in ipairs(tbl) do
		table.insert(new_tbl, 1, item)
	end
	return new_tbl
end

---@param str string
---@param prefix string
---@return boolean
M.str_starts_with = function(str, prefix)
	return str and prefix and (string.sub(str, 1, #prefix) == prefix)
end

---@param str string
---@param suffix string
---@return boolean
M.str_ends_with = function(str, suffix)
	return str
		and suffix
		and (suffix == "" or string.sub(str, -#suffix) == suffix)
end

---@param path string
---@return string?
function M.read_from_path(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

---@param path string
---@param content string
function M.write_to_path(path, content)
	local handle = M.assert(io.open(path, "w"), "Could not open " .. path)
	M.assert(handle:write(content), "Could not write to " .. path)
	handle:close()
end

---@generic T
---@param tbl T
---@return T
M.read_only = function(tbl)
	local proxy = {}
	local mt = {
		__index = tbl,
		__newindex = function(self)
			error(
				(self.__name and (self.__name .. ": ") or "")
					.. "attempt to update a read-only table",
				2
			)
		end,
	}
	setmetatable(proxy, mt)
	return proxy
end

---@param choices string[]
---@param buf_name string
---@param buf_title string
---@param on_select fun(s: string): string
---@param special_choice string?
---@param choice_hints string[]?
M.create_floating_options_window = function(
	choices,
	buf_name,
	buf_title,
	on_select,
	special_choice,
	choice_hints
)
	if #choices == 0 then
		return
	end
	choice_hints = choice_hints or {}

	---@class ChoicePairBimap
	---@field key_to_choice_pair table<string, ChoicePair>
	---@field choice_to_key table<string, string>

	local bimap = {
		key_to_choice_pair = {},
		choice_to_key = {},
	}

	---@param key string
	---@return ChoicePair?
	local function bimap_search_key(key)
		return bimap.key_to_choice_pair[key]
	end

	---@param choice string
	---@return string?
	local function bimap_search_choice(choice)
		return bimap.choice_to_key[choice]
	end

	---@param key string?
	---@param choice_pair [string, integer]
	---@return boolean
	local function bimap_set(key, choice_pair)
		if not key then
			return false
		end
		local choice = choice_pair[1]
		local index = choice_pair[2]
		if index ~= 0 then
			choice = choice:sub(1, index - 1) .. key .. choice:sub(index + 1)
		end
		bimap.key_to_choice_pair[key] = { choice, index }
		bimap.choice_to_key[choice_pair[1]] = key
		return true
	end

	---@return ChoicePairBimap
	local function assign()
		---@alias ChoicePair [string, integer]

		local accepted_keys_str = "1234567890"
			.. "abcdefghijklmnopqrstuvwxyz"
			.. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			.. "!@#$%^&*()"
			.. "-=_+"
		local accepted_key_set = (function()
			local res = {}
			for i = 1, #accepted_keys_str do
				local char = accepted_keys_str:sub(i, i)
				res[char] = 1
			end
			return res
		end)()

		local function find_unused_key()
			for j = 1, #accepted_keys_str do
				local attempted_key = accepted_keys_str:sub(j, j)
				if not bimap_search_key(attempted_key) then
					return attempted_key
				end
			end
			error("Unexpectedly large amount of choices.")
		end

		---@param char string
		---@return string?
		local function toggle_case(char)
			local toggle = char == char:lower() and string.upper or string.lower
			local toggled = toggle(char)
			if char ~= toggled then
				return toggled
			end
		end

		SAFETY_UPPER_LIMIT = #accepted_keys_str
		for i = 1, SAFETY_UPPER_LIMIT do
			local skips = 0
			for _, choice in ipairs(choices) do
				---@type string?, integer?
				local key, index = (function()
					if bimap_search_choice(choice) then
						skips = skips + 1
						return
					end
					local char = choice:sub(i, i)
					if char == "" then
						return find_unused_key(), 0
					end
					if not accepted_key_set[char] then
						return
					end
					if not bimap_search_key(char) then
						return char, i
					end
					local toggled_case = toggle_case(char)
					if not toggled_case then
						return
					end
					if not bimap_search_key(toggled_case) then
						return toggled_case, i
					end
				end)()
				if key then
					bimap_set(key, { choice, index })
				end
			end
			if skips == #choices then
				break
			end
		end
		return bimap
	end

	local buf_id = vim.api.nvim_create_buf(false, true)

	---@param lhs string
	---@param rhs string
	local function set_keymap(lhs, rhs)
		vim.api.nvim_buf_set_keymap(
			buf_id,
			"n",
			lhs,
			rhs,
			{ noremap = true, silent = true }
		)
	end

	---@param line integer
	---@param highlight string
	---@param column_start integer
	---@param column_end integer?
	local function add_highlight(line, highlight, column_start, column_end)
		column_end = column_end or column_start + 1
		vim.api.nvim_buf_add_highlight(
			buf_id,
			-1,
			highlight,
			line,
			column_start,
			column_end
		)
	end

	local width = 32
	for i, choice in ipairs(choices) do
		width = math.max(width, 12 + #choice + 1 + #(choice_hints[i] or "") + 1)
	end
	width = math.min(width, 50)
	local height = math.min(15, #choices + 2 + (special_choice and 1 or 0))
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2 - 1,
		style = "minimal",
		border = "rounded",
		title = buf_title,
		title_pos = "center",
	}

	vim.api.nvim_buf_set_name(buf_id, buf_name)
	vim.api.nvim_open_win(buf_id, true, opts)

	vim.api.nvim_command("hi noCursor blend=100 cterm=strikethrough")
	vim.api.nvim_command("set guicursor+=a:noCursor")

	assign()

	local lines = {}
	for i, choice in ipairs(choices) do
		local key = assert(bimap_search_choice(choice))
		local displayed_choice = bimap_search_key(key)[1]
		local hint = (choice_hints or {})[i] or ""
		table.insert(
			lines,
			("       %s -> %s "):format(key, displayed_choice .. " " .. hint)
		)
		set_keymap(key, on_select(choice))
	end
	table.insert(lines, "")
	table.insert(lines, "   <Esc> -> (exit)")
	if special_choice then
		table.insert(lines, " <Enter> -> " .. special_choice)
		set_keymap("<Enter>", on_select(special_choice))
	end
	vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
	add_highlight(#choices + 1, "ZuzuChoicesEsc", 3, 9)
	add_highlight(#choices + 1, "ZuzuChoicesExit", 12, -1)
	if special_choice then
		add_highlight(#choices + 2, "ZuzuChoicesSpecial", 1, 9)
		add_highlight(#choices + 2, "ZuzuChoicesSpecialChoice", 12, -1)
	end

	for i = 1, #choices do
		add_highlight(
			i - 1,
			({ "ZuzuChoiceKeyOdd", "ZuzuChoiceKeyEven" })[(i % 2) + 1],
			7
		)
		local idx = bimap_search_key(assert(bimap_search_choice(choices[i])))[2]
		if idx ~= 0 then
			add_highlight(
				i - 1,
				({ "ZuzuChoiceOdd", "ZuzuChoiceEven" })[(i % 2) + 1],
				11
					+ bimap_search_key(assert(bimap_search_choice(choices[i])))[2]
			)
		end
		add_highlight(i - 1, "Comment", 12 + #choices[i], -1)
	end

	vim.api.nvim_create_augroup("CloseBufferOnBufferClose", { clear = true })
	vim.api.nvim_create_autocmd("BufLeave", {
		group = "CloseBufferOnBufferClose",
		pattern = "*",
		callback = function()
			if vim.fn.bufnr("%") == buf_id then
				vim.cmd("b#|bwipeout! " .. buf_id)
			end
			vim.api.nvim_command("set guicursor-=a:noCursor")
		end,
	})

	vim.api.nvim_set_current_buf(buf_id)
	set_keymap("<Esc>", ":bd!<CR>")
	vim.api.nvim_set_option_value("modified", false, { buf = buf_id })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf_id })
	vim.cmd("setlocal nowrap")
	vim.cmd("let b:timeoutlen = 0")
end

return M
