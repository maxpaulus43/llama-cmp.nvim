--- LSP context gathering for llama-cmp
--- Gathers diagnostics, hover info, and signature help with caching
local config = require("llama-cmp.config")
local util = require("llama-cmp.util")

local M = {}

--- Cache for LSP results
local cache = {
	hover = { result = nil, time = 0, bufnr = nil, pos = nil },
	signature = { result = nil, time = 0, bufnr = nil, pos = nil },
}

--- Check if cache entry is valid
---@param entry table Cache entry
---@param bufnr number Buffer number
---@param pos table Position {row, col}
---@param ttl_ms number Time-to-live in milliseconds
---@return boolean
local function is_cache_valid(entry, bufnr, pos, ttl_ms)
	if entry.bufnr ~= bufnr then
		return false
	end
	if not entry.pos or entry.pos[1] ~= pos[1] or entry.pos[2] ~= pos[2] then
		return false
	end
	local age = util.now() - entry.time
	return age < ttl_ms
end

--- Update cache entry
---@param cache_key string Cache key ('hover' or 'signature')
---@param result any Result to cache
---@param bufnr number Buffer number
---@param pos table Position
local function update_cache(cache_key, result, bufnr, pos)
	cache[cache_key] = {
		result = result,
		time = util.now(),
		bufnr = bufnr,
		pos = { pos[1], pos[2] },
	}
end

--- Get diagnostics at or near the cursor
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@return table diagnostics list
function M.get_diagnostics(bufnr, cursor)
	local row = cursor[1] - 1 -- Convert to 0-indexed

	-- Get diagnostics for the current line
	local diagnostics = vim.diagnostic.get(bufnr, { lnum = row })

	-- If no diagnostics on current line, get nearby ones (within 3 lines)
	if #diagnostics == 0 then
		local all_diagnostics = vim.diagnostic.get(bufnr)
		for _, d in ipairs(all_diagnostics) do
			if math.abs(d.lnum - row) <= 3 then
				table.insert(diagnostics, d)
			end
		end
	end

	return diagnostics
end

--- Format diagnostics for context
---@param diagnostics table List of diagnostics
---@return string formatted text
function M.format_diagnostics(diagnostics)
	if #diagnostics == 0 then
		return ""
	end

	local severity_names = {
		[vim.diagnostic.severity.ERROR] = "Error",
		[vim.diagnostic.severity.WARN] = "Warning",
		[vim.diagnostic.severity.INFO] = "Info",
		[vim.diagnostic.severity.HINT] = "Hint",
	}

	local lines = {}
	local seen = {} -- Deduplicate messages

	for _, d in ipairs(diagnostics) do
		local msg = d.message:gsub("\n", " "):gsub("%s+", " ")
		if not seen[msg] then
			seen[msg] = true
			local severity = severity_names[d.severity] or "Unknown"
			table.insert(lines, string.format("[%s] %s", severity, msg))
		end
	end

	return table.concat(lines, "\n")
end

--- Get hover information at cursor
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@param timeout_ms number|nil Timeout in milliseconds
---@return string|nil hover text
function M.get_hover(bufnr, cursor, timeout_ms)
	local opts = config.get()
	timeout_ms = timeout_ms or opts.context.lsp.timeout_ms
	local cache_ttl = opts.context.lsp.cache_ttl_ms

	-- Check cache
	if is_cache_valid(cache.hover, bufnr, cursor, cache_ttl) then
		return cache.hover.result
	end

	-- Check if any client supports hover
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	local has_hover = false
	for _, client in ipairs(clients) do
		if client.server_capabilities.hoverProvider then
			has_hover = true
			break
		end
	end

	if not has_hover then
		return nil
	end

	-- Make synchronous LSP request
	local params = vim.lsp.util.make_position_params()
	local results = vim.lsp.buf_request_sync(bufnr, "textDocument/hover", params, timeout_ms)

	if not results then
		update_cache("hover", nil, bufnr, cursor)
		return nil
	end

	-- Extract hover content from results
	for _, res in pairs(results) do
		if res.result and res.result.contents then
			local contents = res.result.contents
			local text = nil

			if type(contents) == "string" then
				text = contents
			elseif type(contents) == "table" then
				if contents.value then
					-- MarkupContent
					text = contents.value
				elseif contents.kind then
					text = contents.value or ""
				elseif #contents > 0 then
					-- Array of MarkedString
					local parts = {}
					for _, part in ipairs(contents) do
						if type(part) == "string" then
							table.insert(parts, part)
						elseif part.value then
							table.insert(parts, part.value)
						end
					end
					text = table.concat(parts, "\n")
				end
			end

			if text and text ~= "" then
				-- Clean up markdown code blocks for context
				text = text:gsub("```%w*\n?", ""):gsub("\n?```", "")
				update_cache("hover", text, bufnr, cursor)
				return text
			end
		end
	end

	update_cache("hover", nil, bufnr, cursor)
	return nil
end

--- Get signature help at cursor
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@param timeout_ms number|nil Timeout in milliseconds
---@return string|nil signature text
function M.get_signature(bufnr, cursor, timeout_ms)
	local opts = config.get()
	timeout_ms = timeout_ms or opts.context.lsp.timeout_ms
	local cache_ttl = opts.context.lsp.cache_ttl_ms

	-- Check cache
	if is_cache_valid(cache.signature, bufnr, cursor, cache_ttl) then
		return cache.signature.result
	end

	-- Check if any client supports signature help
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	local has_signature = false
	for _, client in ipairs(clients) do
		if client.server_capabilities.signatureHelpProvider then
			has_signature = true
			break
		end
	end

	if not has_signature then
		return nil
	end

	-- Make synchronous LSP request
	local params = vim.lsp.util.make_position_params()
	local results = vim.lsp.buf_request_sync(bufnr, "textDocument/signatureHelp", params, timeout_ms)

	if not results then
		update_cache("signature", nil, bufnr, cursor)
		return nil
	end

	-- Extract signature from results
	for _, res in pairs(results) do
		if res.result and res.result.signatures and #res.result.signatures > 0 then
			local active_sig = res.result.activeSignature or 0
			local sig = res.result.signatures[active_sig + 1] or res.result.signatures[1]

			if sig and sig.label then
				local text = sig.label

				-- Add parameter documentation if available
				if sig.parameters and res.result.activeParameter then
					local param = sig.parameters[res.result.activeParameter + 1]
					if param and param.documentation then
						local doc = param.documentation
						if type(doc) == "table" then
							doc = doc.value or ""
						end
						if doc ~= "" then
							text = text .. " -- " .. doc:gsub("\n", " ")
						end
					end
				end

				update_cache("signature", text, bufnr, cursor)
				return text
			end
		end
	end

	update_cache("signature", nil, bufnr, cursor)
	return nil
end

--- Gather all LSP context
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@return table context { diagnostics, hover, signature }
function M.gather(bufnr, cursor)
	local opts = config.get()
	local lsp_opts = opts.context.lsp

	if not lsp_opts.enabled then
		return { diagnostics = "", hover = nil, signature = nil }
	end

	local diagnostics = ""
	local hover = nil
	local signature = nil

	if lsp_opts.diagnostics then
		local diags = M.get_diagnostics(bufnr, cursor)
		diagnostics = M.format_diagnostics(diags)
	end

	if lsp_opts.hover then
		hover = M.get_hover(bufnr, cursor, lsp_opts.timeout_ms)
	end

	if lsp_opts.signature_help then
		signature = M.get_signature(bufnr, cursor, lsp_opts.timeout_ms)
	end

	return {
		diagnostics = diagnostics,
		hover = hover,
		signature = signature,
	}
end

--- Format all LSP context as a comment block
---@param lsp_context table LSP context from gather()
---@param filetype string File type for comment syntax
---@return string formatted context
function M.format_context(lsp_context, filetype)
	local parts = {}

	if lsp_context.hover and lsp_context.hover ~= "" then
		-- Take first line or first 200 chars of hover
		local hover = lsp_context.hover:match("^[^\n]+") or lsp_context.hover
		hover = util.truncate(hover, 200)
		table.insert(parts, "Type: " .. hover)
	end

	if lsp_context.signature and lsp_context.signature ~= "" then
		local sig = util.truncate(lsp_context.signature, 200)
		table.insert(parts, "Signature: " .. sig)
	end

	if lsp_context.diagnostics and lsp_context.diagnostics ~= "" then
		-- Take first diagnostic only to keep context small
		local diag = lsp_context.diagnostics:match("^[^\n]+") or lsp_context.diagnostics
		table.insert(parts, "Diagnostic: " .. diag)
	end

	if #parts == 0 then
		return ""
	end

	-- Format as comments
	local prefix, suffix = util.get_comment_string(filetype)
	local lines = {}

	for _, part in ipairs(parts) do
		table.insert(lines, prefix .. part .. suffix)
	end

	return table.concat(lines, "\n")
end

--- Clear the cache
function M.clear_cache()
	cache.hover = { result = nil, time = 0, bufnr = nil, pos = nil }
	cache.signature = { result = nil, time = 0, bufnr = nil, pos = nil }
end

return M
