local M = {}

M.RETVAL = "RETVAL"

---@param function_name string
---@param arg_name string?
---@param expected_type string
---@param actual string
---@overload fun(function_name: string, triplet: {[1]: any, [2]: string, [3]: string?}): string
---@return string errmsg
M.invalid_type_error = function(function_name, arg_name, expected_type, actual)
	arg_name = arg_name or M.RETVAL
	if type(arg_name) == type({}) then
		expected_type = arg_name[2]
		actual = type(arg_name[1])
		arg_name = arg_name[3] or M.RETVAL
	end
	return (
		arg_name ~= M.RETVAL
			and ("Invalid type for `" .. arg_name .. "` in `")
		or "Invalid type returned from `"
	)
		.. function_name
		.. "`."
		.. '\nExpected type "'
		.. expected_type
		.. '" but got "'
		.. actual
		.. '".'
end

---@param function_name string
---@param arg_name string?
---@param expected_class table
---@param actual any
---@overload fun(function_name: string, triplet: {[1]: any, [2]: table, [3]: string?}): string
---@return string
M.invalid_instance_error = function(
	function_name,
	arg_name,
	expected_class,
	actual
)
	arg_name = arg_name or M.RETVAL
	if type(arg_name) == type({}) then
		expected_class = arg_name[2]
		actual = arg_name[1]
		arg_name = arg_name[3] or M.RETVAL
	end
	expected_class = expected_class.__name
	if actual then
		if actual.__index then
			actual = actual.__index.__name or tostring(actual.__index)
		else
			actual = "(actual = " .. tostring(actual) .. ")"
		end
	end
	return (
		arg_name ~= M.RETVAL
			and ("Invalid base class for `" .. arg_name .. "` in `")
		or "Invalid base class returned from `"
	)
		.. function_name
		.. "`."
		.. '\nExpected base class "'
		.. expected_class
		.. '" and got "'
		.. tostring(actual)
		.. '".'
end

---@param function_name string
---@param data {[1]: any, [2]: string, [3]: string?}[]
---@return string? errmsg
M.types = function(function_name, data)
	for _, item in ipairs(data) do
		local is_correct = true;
		(function()
			local elem = item[1]
			local expected_types = {}
			for type in item[2]:gmatch("[^|]*") do
				table.insert(expected_types, type)
			end
			for _, expected_type in ipairs(expected_types) do
				if expected_type:sub(#expected_type, #expected_type) == "?" then
					if elem == nil then
						return
					end
					expected_type =
						string.sub(expected_type, 1, #expected_type - 1)
				end
				if type(elem) == expected_type then
					return
				end
			end
			is_correct = false
		end)()
		if not is_correct then
			return M.invalid_type_error(function_name, item)
		end
	end
	return nil
end

---@param function_name string
---@param list any[]
---@param arg_name string
---@param expected_type string
---@return string? errmsg
M.types_in_list = function(function_name, list, arg_name, expected_type)
	arg_name = arg_name or M.RETVAL
	local err = M.types(function_name, { { list, "table", arg_name } })
	if err then
		return err
	end
	for i, value in ipairs(list) do
		local new_function_name = arg_name == M.RETVAL
				and (function_name .. "(...)[" .. i .. "]")
			or function_name
		local new_arg_name = arg_name == M.RETVAL and M.RETVAL
			or (arg_name .. "[" .. i .. "]")
		err = M.types(
			new_function_name,
			{ { value, expected_type, new_arg_name } }
		)
		if err then
			return err
		end
	end
	return nil
end

---@param function_name string
---@param data {[1]: any, [2]: table, [3]: string?}[]
---@return string? errmsg
M.are_instances = function(function_name, data)
	for _, item in ipairs(data) do
		if not item[1] then
			return M.invalid_instance_error(function_name, item)
		end
		if type(item[1]) ~= type({}) then
			return M.invalid_instance_error(function_name, item)
		end
		if item[1].__index ~= item[2] then
			return M.invalid_instance_error(function_name, item)
		end
	end
	return nil
end

return M
