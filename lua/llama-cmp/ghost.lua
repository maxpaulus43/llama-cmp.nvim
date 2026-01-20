--- Ghost text rendering for llama-cmp
--- Renders multi-line virtual text at cursor position using extmarks
local config = require("llama-cmp.config")

local M = {}

--- Namespace for extmarks
local ns_id = vim.api.nvim_create_namespace("llama-cmp")

--- Extmark ID (reused for updates)
local extmark_id = 1

--- Current ghost text state
local state = {
	bufnr = nil,
	row = nil,
	col = nil,
	text = nil,
	visible = false,
}

--- Setup highlight groups
local function setup_highlights()
	-- Default to Comment style, but allow customization
	local cfg = config.get()
	local hl = cfg.highlight

	-- Create our own highlight group that links to the configured one
	if vim.fn.hlexists("LlamaCmpGhost") == 0 then
		vim.api.nvim_set_hl(0, "LlamaCmpGhost", { link = hl, default = true })
	end
end

--- Show ghost text at the specified position
---@param text string The suggestion text (may contain newlines)
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col} (1-indexed row, 0-indexed col)
function M.show(text, bufnr, cursor)
	if not text or text == "" then
		M.clear()
		return
	end

	setup_highlights()

	-- Clear any existing ghost text
	pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)

	-- Split text into lines
	local lines = vim.split(text, "\n", { plain = true })

	if #lines == 0 then
		return
	end

	-- Build extmark options
	local extmark_opts = {
		id = extmark_id,
		virt_text = { { lines[1], "LlamaCmpGhost" } },
		virt_text_pos = "inline",
		hl_mode = "combine",
		priority = 1000, -- High priority to show above other virtual text
	}

	-- For multi-line completions, add virt_lines
	if #lines > 1 then
		extmark_opts.virt_lines = {}
		for i = 2, #lines do
			table.insert(extmark_opts.virt_lines, { { lines[i], "LlamaCmpGhost" } })
		end
	end

	-- Place the extmark
	local row = cursor[1] - 1 -- Convert to 0-indexed
	local col = cursor[2]

	local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, row, col, extmark_opts)

	if ok then
		state.bufnr = bufnr
		state.row = cursor[1]
		state.col = cursor[2]
		state.text = text
		state.visible = true
	else
		-- Fallback: try with virt_text_pos = "eol" if inline fails
		extmark_opts.virt_text_pos = "eol"
		extmark_opts.virt_text_win_col = col

		ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, row, col, extmark_opts)
		if ok then
			state.bufnr = bufnr
			state.row = cursor[1]
			state.col = cursor[2]
			state.text = text
			state.visible = true
		end
	end
end

--- Update existing ghost text (for streaming)
---@param text string The updated suggestion text
function M.update(text)
	if not state.visible or not state.bufnr then
		return
	end

	M.show(text, state.bufnr, { state.row, state.col })
end

--- Clear ghost text
function M.clear()
	if state.bufnr then
		pcall(vim.api.nvim_buf_del_extmark, state.bufnr, ns_id, extmark_id)
	end

	-- Also clear from current buffer just in case
	local current_buf = vim.api.nvim_get_current_buf()
	pcall(vim.api.nvim_buf_del_extmark, current_buf, ns_id, extmark_id)

	state.bufnr = nil
	state.row = nil
	state.col = nil
	state.text = nil
	state.visible = false
end

--- Check if ghost text is currently visible
---@return boolean
function M.is_visible()
	return state.visible
end

--- Get the current ghost text
---@return string|nil
function M.get_text()
	if state.visible then
		return state.text
	end
	return nil
end

--- Get the current ghost text position
---@return table|nil position {bufnr, row, col} or nil
function M.get_position()
	if state.visible then
		return {
			bufnr = state.bufnr,
			row = state.row,
			col = state.col,
		}
	end
	return nil
end

--- Check if cursor is at the ghost text position
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col}
---@return boolean
function M.is_at_position(bufnr, cursor)
	if not state.visible then
		return false
	end

	return state.bufnr == bufnr and state.row == cursor[1] and state.col == cursor[2]
end

--- Get the namespace ID (for external use if needed)
---@return number
function M.get_namespace()
	return ns_id
end

return M
