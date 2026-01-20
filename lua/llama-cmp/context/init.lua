--- Context orchestration for llama-cmp
--- Gathers buffer and LSP context and builds FIM prompts
local config = require("llama-cmp.config")
local buffer = require("llama-cmp.context.buffer")
local lsp = require("llama-cmp.context.lsp")

local M = {}

--- Gather all context for completion
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@return table context
function M.gather(bufnr, cursor)
	local opts = config.get()

	-- Get buffer context
	local prefix = buffer.get_prefix(bufnr, cursor, opts.context.max_prefix_lines)
	local suffix = buffer.get_suffix(bufnr, cursor, opts.context.max_suffix_lines)
	local metadata = buffer.get_metadata(bufnr)

	-- Get LSP context
	local lsp_context = lsp.gather(bufnr, cursor)
	local lsp_formatted = lsp.format_context(lsp_context, metadata.filetype)

	return {
		prefix = prefix,
		suffix = suffix,
		metadata = metadata,
		lsp = lsp_context,
		lsp_formatted = lsp_formatted,
	}
end

--- Build a FIM prompt from context
---@param context table Context from gather()
---@return string prompt
function M.build_prompt(context)
	local opts = config.get()
	local fim = opts.fim

	local parts = {}

	-- Add file info as a comment at the start
	if context.metadata.filename and context.metadata.filename ~= "" then
		local prefix_comment, suffix_comment = require("llama-cmp.util").get_comment_string(context.metadata.filetype)
		table.insert(parts, prefix_comment .. "File: " .. context.metadata.filename .. suffix_comment .. "\n")
	end

	-- Add LSP context as comments (if available)
	if context.lsp_formatted and context.lsp_formatted ~= "" then
		table.insert(parts, context.lsp_formatted .. "\n")
	end

	-- Build FIM prompt
	-- Format: <PREFIX>code before cursor<SUFFIX>code after cursor<MIDDLE>
	table.insert(parts, fim.prefix)
	table.insert(parts, context.prefix)
	table.insert(parts, fim.suffix)
	table.insert(parts, context.suffix)
	table.insert(parts, fim.middle)

	return table.concat(parts, "")
end

--- Build a simple prompt without FIM (for testing/fallback)
---@param context table Context from gather()
---@return string prompt
function M.build_simple_prompt(context)
	local parts = {}

	-- Add file info
	if context.metadata.filename and context.metadata.filename ~= "" then
		table.insert(parts, "-- File: " .. context.metadata.filename .. "\n")
	end

	-- Add LSP context
	if context.lsp_formatted and context.lsp_formatted ~= "" then
		table.insert(parts, context.lsp_formatted .. "\n")
	end

	-- Add prefix code
	table.insert(parts, context.prefix)

	return table.concat(parts, "")
end

--- Get context and build prompt in one call
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@return string prompt, table context
function M.get_prompt(bufnr, cursor)
	local context = M.gather(bufnr, cursor)
	local prompt = M.build_prompt(context)
	return prompt, context
end

return M
