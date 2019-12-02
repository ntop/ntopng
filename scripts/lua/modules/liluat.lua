--[[
-- liluat - Lightweight Lua Template engine
--
-- Project page: https://github.com/FSMaxB/liluat
--
-- liluat is based on slt2 by henix, see https://github.com/henix/slt2
--
-- Copyright © 2016 Max Bruckner
-- Copyright © 2011-2016 henix
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is furnished
-- to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
-- IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local liluat = {
	private = {} --used to expose private functions for testing
}

-- print the current version
liluat.version = function ()
	return "1.2.0"
end

-- returns a string containing the fist line until the last line
local function string_lines(lines, first, last)
	-- allow negative line numbers
	first = (first >= 1) and first or 1

	local start_position
	local current_position = 1
	local line_counter = 1
	repeat
		if line_counter == first then
			start_position = current_position
		end
		current_position = lines:find('\n', current_position + 1, true)
		line_counter = line_counter + 1
	until (line_counter == (last + 1)) or (not current_position)

	return lines:sub(start_position, current_position)
end
liluat.private.string_lines = string_lines

-- escape a string for use in lua patterns
-- (this simply prepends all non alphanumeric characters with '%'
local function escape_pattern(text)
	return text:gsub("([^%w])", "%%%1" --[[function (match) return "%"..match end--]])
end
liluat.private.escape_pattern = escape_pattern

-- recursively copy a table
local function clone_table(table)
	local clone = {}

	for key, value in pairs(table) do
		if type(value) == "table" then
			clone[key] = clone_table(value)
		else
			clone[key] = value
		end
	end

	return clone
end
liluat.private.clone_table = clone_table

-- recursively merge two tables, the second one has precedence
-- if 'shallow' is set, the second table isn't copied recursively,
-- its content is only referenced instead
local function merge_tables(a, b, shallow)
	a = a or {}
	b = b or {}

	local merged = clone_table(a)

	for key, value in pairs(b) do
		if (type(value) == "table") and (not shallow) then
			if a[key] then
				merged[key] = merge_tables(a[key], value)
			else
				merged[key] = clone_table(value)
			end
		else
			merged[key] = value
		end
	end

	return merged
end
liluat.private.merge_tables = merge_tables

local default_options = {
	start_tag = "{{",
	end_tag = "}}",
	trim_right = "code",
	trim_left = "code"
}

-- initialise table of options (use the provided, default otherwise)
local function initialise_options(options)
	return merge_tables(default_options, options)
end

-- creates an iterator that iterates over all chunks in the given template
-- a chunk is either a template delimited by start_tag and end_tag or a normal text
-- the iterator also returns the type of the chunk as second return value
local function all_chunks(template, options)
	options = initialise_options(options)

	-- pattern to match a template chunk
	local template_pattern = escape_pattern(options.start_tag) .. "([+-]?)(.-)([+-]?)" .. escape_pattern(options.end_tag)
	local include_pattern = "^"..escape_pattern(options.start_tag) .. "[+-]?include:(.-)[+-]?" .. escape_pattern(options.end_tag)
	local expression_pattern = "^"..escape_pattern(options.start_tag) .. "[+-]?=(.-)[+-]?" .. escape_pattern(options.end_tag)
	local position = 1

	return function ()
		if not position then
			return nil
		end

		local template_start, template_end, trim_left, template_capture, trim_right = template:find(template_pattern, position)

		local chunk = {}
		if template_start == position then -- next chunk is a template chunk
			if trim_left == "+" then
				chunk.trim_left = false
			elseif trim_left == "-" then
				chunk.trim_left = true
			end
			if trim_right == "+" then
				chunk.trim_right = false
			elseif trim_right == "-" then
				chunk.trim_right = true
			end

			local include_start, include_end, include_capture = template:find(include_pattern, position)
			local expression_start, expression_end, expression_capture
			if not include_start then
				expression_start, expression_end, expression_capture = template:find(expression_pattern, position)
			end

			if include_start then
				chunk.type = "include"
				chunk.text = include_capture
			elseif expression_start then
				chunk.type = "expression"
				chunk.text = expression_capture
			else
				chunk.type = "code"
				chunk.text = template_capture
			end

			position = template_end + 1
			return chunk
		elseif template_start then -- next chunk is a text chunk
			chunk.type = "text"
			chunk.text = template:sub(position, template_start - 1)
			position = template_start
			return chunk
		else -- no template chunk found --> either text chunk until end of file or no chunk at all
			chunk.text = template:sub(position)
			chunk.type = "text"
			position = nil
			return (#chunk.text > 0) and chunk or nil
		end
	end
end
liluat.private.all_chunks = all_chunks

local function read_entire_file(path)
	assert(path)
	local file = assert(io.open(path))
	local file_content = file:read('*a')
	file:close()
	return file_content
end
liluat.private.read_entire_file = read_entire_file

-- a whitelist of allowed functions
local sandbox_whitelist = {
	ipairs = ipairs,
	next = next,
	pairs = pairs,
	rawequal = rawequal,
	rawget = rawget,
	rawset = rawset,
	select = select,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	string = string,
	table = table,
	math = math,
	os = {
		date = os.date,
		difftime = os.difftime,
		time = os.time,
	},
	coroutine = coroutine
}

-- puts line numbers in front of a string and optionally highlights a single line
local function prepend_line_numbers(lines, first, highlight)
	first = (first and (first >= 1)) and first or 1
	lines = lines:gsub("\n$", "") -- make sure the last line isn't empty
	lines = lines:gsub("^\n", "") -- make sure the first line isn't empty

	local current_line = first + 1
	return string.format("%3d:  ", first) .. lines:gsub('\n', function ()
		local highlight_char = '  '
		if current_line == tonumber(highlight) then
			highlight_char = '> '
		end

		local replacement = string.format("\n%3d:%s", current_line, highlight_char)
		current_line = current_line + 1

		return replacement
	end)
end
liluat.private.prepend_line_numbers = prepend_line_numbers

-- creates a function in a sandbox from a given code,
-- name of the execution context and an environment
-- that will be available inside the sandbox,
-- optionally overwrite the whitelist
local function sandbox(code, name, environment, whitelist, reference)
	whitelist = whitelist or sandbox_whitelist
	name = name or 'unknown'

	-- prepare the environment
	environment = merge_tables(whitelist, environment, reference)

	local func
	local error_message
	if setfenv then --Lua 5.1 and compatible
		if code:byte(1) == 27 then
			error("Lua bytecode not permitted.", 2)
		end
		func, error_message = loadstring(code)
		if func then
			setfenv(func, environment)
		end
	else -- Lua 5.2 and later
		func, error_message = load(code, name, 't', environment)
	end

	-- handle compile error and print pretty error message
	if not func then
		local line_number, message = error_message:match(":(%d+):(.*)")
		-- lines before and after the error
		local lines = string_lines(code, line_number - 3, line_number + 3)
		error(
			'Syntax error in sandboxed code "' .. name .. '" in line ' .. line_number .. ':\n'
			.. message .. '\n\n'
			..  prepend_line_numbers(lines, line_number - 3, line_number),
			3
		)
	end

	return func
end
liluat.private.sandbox = sandbox

local function parse_string_literal(string_literal)
	return sandbox('return' .. string_literal, nil, nil, {})()
end
liluat.private.parse_string_literal = parse_string_literal

-- add an include to the include_list and throw an error if
-- an inclusion cycle is detected
local function add_include_and_detect_cycles(include_list, path)
	local parent = include_list[0]
	while parent do -- while the root hasn't been reached
		if parent[path] then
			error("Cyclic inclusion detected")
		end

		parent = parent[0]
	end

	include_list[path] = {
		[0] = include_list
	}
end
liluat.private.add_include_and_detect_cycles = add_include_and_detect_cycles

-- extract the name of a directory from a path
local function dirname(path)
	return path:match("^(.*/).-$") or ""
end
liluat.private.dirname = dirname

-- splits a template into chunks
-- chunks are either a template delimited by start_tag and end_tag
-- or a text chunk (everything else)
-- @return table
local function parse(template, options, output, include_list, current_path)
	options = initialise_options(options)
	current_path = current_path or "." -- current include path

	include_list = include_list or {} -- a list of files that were included
	local output = output or {}

	for chunk in all_chunks(template, options) do
		-- handle includes
		if chunk.type == "include" then -- include chunk
			local include_path_literal = chunk.text
			local path = parse_string_literal(include_path_literal)

			-- build complete path
			if path:find("^/") then
				--absolute path, don't modify
			elseif options.base_path then
				path = options.base_path .. "/" .. path
			else
				path = dirname(current_path) .. path
			end

			add_include_and_detect_cycles(include_list, path)

			local included_template = read_entire_file(path)
			parse(included_template, options, output, include_list[path], path)
		elseif (chunk.type == "text") and output[#output] and (output[#output].type == "text") then
			-- ensure that no two text chunks follow each other
			output[#output].text = output[#output].text .. chunk.text
		else -- other chunk
			table.insert(output, chunk)
		end

	end

	return output
end
liluat.private.parse = parse

-- inline included template files
-- @return string
function liluat.inline(template, options, start_path)
	options = initialise_options(options)

	local output = {}
	for _,chunk in ipairs(parse(template, options, nil, nil, start_path)) do
		if chunk.type == "expression" then
			table.insert(output, options.start_tag .. "=" .. chunk.text .. options.end_tag)
		elseif chunk.type == "code" then
			table.insert(output, options.start_tag .. chunk.text .. options.end_tag)
		else
			table.insert(output, chunk.text)
		end
	end

	return table.concat(output)
end

-- @return { string }
function liluat.get_dependencies(template, options, start_path)
	options = initialise_options(options)

	local include_list = {}
	parse(template, options, nil, include_list, start_path)

	local dependencies = {}
	local have_seen = {} -- list of includes that were already added
	local function recursive_traversal(list)
		for key, value in pairs(list) do
			if (type(key) == "string") and (not have_seen[key]) then
				have_seen[key] = true
				table.insert(dependencies, key)
				recursive_traversal(value)
			end
		end
	end

	recursive_traversal(include_list)
	return dependencies
end

-- compile a template into lua code
-- @return { name = string, code = string / function}
function liluat.compile(template, options, template_name, start_path)
	options = initialise_options(options)
	template_name = template_name or 'liluat.compile'

	local output_function = "__liluat_output_function"

	-- split the template string into chunks
	local lexed_template = parse(template, options, nil, nil, start_path)

	-- table of code fragments the template is compiled into
	local lua_code = {}

	for i, chunk in ipairs(lexed_template) do
		-- check if the chunk is a template (either code or expression)
		if chunk.type == "expression" then
			table.insert(lua_code, output_function..'('..chunk.text..')')
		elseif chunk.type == "code" then
			table.insert(lua_code, chunk.text)
		else --text chunk
			-- determine if this block needs to be trimmed right
			-- (strip newline)
			local trim_right = false
			if lexed_template[i - 1] and (lexed_template[i - 1].trim_right == true) then
				trim_right = true
			elseif lexed_template[i - 1] and (lexed_template[i - 1].trim_right == false) then
				trim_right = false
			elseif options.trim_right == "all" then
				trim_right = true
			elseif options.trim_right == "code" then
				trim_right = lexed_template[i - 1] and (lexed_template[i - 1].type == "code")
			elseif options.trim_right == "expression" then
				trim_right = lexed_template[i - 1] and (lexed_template[i - 1].type == "expression")
			end

			-- determine if this block needs to be trimmed left
			-- (strip whitespaces in front)
			local trim_left = false
			if lexed_template[i + 1] and (lexed_template[i + 1].trim_left == true) then
				trim_left = true
			elseif lexed_template[i + 1] and (lexed_template[i + 1].trim_left == false) then
				trim_left = false
			elseif options.trim_left == "all" then
				trim_left = true
			elseif options.trim_left == "code" then
				trim_left = lexed_template[i + 1] and (lexed_template[i + 1].type == "code")
			elseif options.trim_left == "expression" then
				trim_left = lexed_template[i + 1] and (lexed_template[i + 1].type == "expression")
			end

			if trim_right and trim_left then
				-- both at once
				if i == 1 then
					if chunk.text:find("^.*\n") then
						chunk.text = chunk.text:match("^(.*\n)%s-$")
					elseif chunk.text:find("^%s-$") then
						chunk.text = ""
					end
				elseif chunk.text:find("^\n") then --have to trim a newline
					if chunk.text:find("^\n.*\n") then --at least two newlines
						chunk.text = chunk.text:match("^\n(.*\n)%s-$") or chunk.text:match("^\n(.*)$")
					elseif chunk.text:find("^\n%s-$") then
						chunk.text = ""
					else
						chunk.text = chunk.text:gsub("^\n", "")
					end
				else
					chunk.text = chunk.text:match("^(.*\n)%s-$") or chunk.text
				end
			elseif trim_left then
				if i == 1 and chunk.text:find("^%s-$") then
					chunk.text = ""
				else
					chunk.text = chunk.text:match("^(.*\n)%s-$") or chunk.text
				end
			elseif trim_right then
				chunk.text = chunk.text:gsub("^\n", "")
			end
			if not (chunk.text == "") then
				table.insert(lua_code, output_function..'('..string.format("%q", chunk.text)..')')
			end
		end
	end

	return {
		name = template_name,
		code = table.concat(lua_code, '\n')
	}
end

-- compile a file
-- @return { name = string, code = string / function }
function liluat.compile_file(filename, options)
	return liluat.compile(read_entire_file(filename), options, filename, filename)
end

-- @return a coroutine function
function liluat.render_coroutine(template, environment, options)
	options = initialise_options(options)
	environment = merge_tables({__liluat_output_function = coroutine.yield}, environment, options.reference)

	return sandbox(template.code, template.name, environment, nil, options.reference)
end

-- @return string
function liluat.render(t, env, options)
	options = initialise_options(options)

	local result = {}

	-- add closure that renders the text into the result table
	env = merge_tables({
			__liluat_output_function = function (text)
				table.insert(result, text) end
			},
			env,
			options.reference
		)

	-- compile and run the lua code
	local render_function = sandbox(t.code, t.name, env, nil, options.reference)
	local status, error_message = pcall(render_function)
	if not status then
		local line_number, message = error_message:match(":(%d+):(.*)")
		-- lines before and after the error
		local lines = string_lines(t.code, line_number - 3, line_number + 3)
		error(
			'Runtime error in sandboxed code "' .. t.name .. '" in line ' .. line_number .. ':\n'
			.. message .. '\n\n'
			..  prepend_line_numbers(lines, line_number - 3, line_number),
			2
		)
	end

	return table.concat(result)
end

return liluat
