--- Utility functions for llama-cmp
local M = {}

--- Deep merge two tables, with t2 values taking precedence
---@param t1 table Base table
---@param t2 table Override table
---@return table Merged table
function M.deep_merge(t1, t2)
	local result = vim.deepcopy(t1)
	for k, v in pairs(t2) do
		if type(v) == "table" and type(result[k]) == "table" then
			result[k] = M.deep_merge(result[k], v)
		else
			result[k] = v
		end
	end
	return result
end

--- Check if a value exists in a list
---@param list table List to search
---@param value any Value to find
---@return boolean
function M.list_contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

--- Get current timestamp in milliseconds
---@return number
function M.now()
	return vim.loop.now()
end

--- Debounce a function
---@param fn function Function to debounce
---@param ms number Delay in milliseconds
---@return function, function Debounced function and cancel function
function M.debounce(fn, ms)
	local timer = nil

	local function debounced(...)
		local args = { ... }
		if timer then
			vim.fn.timer_stop(timer)
		end
		timer = vim.fn.timer_start(ms, function()
			timer = nil
			fn(unpack(args))
		end)
	end

	local function cancel()
		if timer then
			vim.fn.timer_stop(timer)
			timer = nil
		end
	end

	return debounced, cancel
end

--- Get the comment string for a filetype
---@param filetype string
---@return string prefix, string suffix
function M.get_comment_string(filetype)
	-- Common comment patterns
	local patterns = {
		lua = { "-- ", "" },
		python = { "# ", "" },
		javascript = { "// ", "" },
		typescript = { "// ", "" },
		javascriptreact = { "// ", "" },
		typescriptreact = { "// ", "" },
		c = { "// ", "" },
		cpp = { "// ", "" },
		rust = { "// ", "" },
		go = { "// ", "" },
		java = { "// ", "" },
		kotlin = { "// ", "" },
		swift = { "// ", "" },
		ruby = { "# ", "" },
		perl = { "# ", "" },
		bash = { "# ", "" },
		sh = { "# ", "" },
		zsh = { "# ", "" },
		fish = { "# ", "" },
		vim = { '" ', "" },
		html = { "<!-- ", " -->" },
		xml = { "<!-- ", " -->" },
		css = { "/* ", " */" },
		scss = { "// ", "" },
		less = { "// ", "" },
		sql = { "-- ", "" },
		haskell = { "-- ", "" },
		elm = { "-- ", "" },
		ocaml = { "(* ", " *)" },
		fsharp = { "// ", "" },
		clojure = { ";; ", "" },
		lisp = { ";; ", "" },
		scheme = { ";; ", "" },
		erlang = { "% ", "" },
		elixir = { "# ", "" },
		r = { "# ", "" },
		matlab = { "% ", "" },
		julia = { "# ", "" },
		php = { "// ", "" },
		yaml = { "# ", "" },
		toml = { "# ", "" },
		ini = { "; ", "" },
		dockerfile = { "# ", "" },
		make = { "# ", "" },
		cmake = { "# ", "" },
		zig = { "// ", "" },
		nim = { "# ", "" },
		v = { "// ", "" },
		d = { "// ", "" },
		crystal = { "# ", "" },
		nix = { "# ", "" },
	}

	local pattern = patterns[filetype]
	if pattern then
		return pattern[1], pattern[2]
	end

	-- Try to get from vim's commentstring
	local cs = vim.bo.commentstring
	if cs and cs ~= "" then
		local prefix, suffix = cs:match("^(.-)%%s(.-)$")
		if prefix then
			return prefix, suffix or ""
		end
	end

	-- Default to //
	return "// ", ""
end

--- Truncate a string to a maximum length
---@param str string
---@param max_len number
---@return string
function M.truncate(str, max_len)
	if #str <= max_len then
		return str
	end
	return str:sub(1, max_len)
end

--- Split string by newlines, preserving empty lines
---@param str string
---@return table
function M.split_lines(str)
	local lines = {}
	for line in (str .. "\n"):gmatch("([^\n]*)\n") do
		table.insert(lines, line)
	end
	return lines
end

--- Log a debug message (only if debug is enabled)
---@param msg string
---@param ... any
function M.debug(msg, ...)
	if vim.g.llama_cmp_debug then
		vim.notify(string.format("[llama-cmp] " .. msg, ...), vim.log.levels.DEBUG)
	end
end

--- Log an info message
---@param msg string
---@param ... any
function M.info(msg, ...)
	vim.notify(string.format("[llama-cmp] " .. msg, ...), vim.log.levels.INFO)
end

--- Log a warning message
---@param msg string
---@param ... any
function M.warn(msg, ...)
	vim.notify(string.format("[llama-cmp] " .. msg, ...), vim.log.levels.WARN)
end

--- Log an error message
---@param msg string
---@param ... any
function M.error(msg, ...)
	vim.notify(string.format("[llama-cmp] " .. msg, ...), vim.log.levels.ERROR)
end

return M
