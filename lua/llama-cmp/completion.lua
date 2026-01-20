--- Completion state machine for llama-cmp
--- Manages debouncing, completion requests, and state transitions
local config = require("llama-cmp.config")
local context = require("llama-cmp.context")
local client = require("llama-cmp.client")
local ghost = require("llama-cmp.ghost")
local util = require("llama-cmp.util")

local M = {}

--- Completion states
local STATE = {
  IDLE = "idle",
  PENDING = "pending",     -- Waiting for debounce
  STREAMING = "streaming", -- Receiving tokens
  SHOWING = "showing",     -- Suggestion visible, waiting for user action
}

--- Current state
local state = {
  status = STATE.IDLE,
  suggestion = "",
  cursor_pos = nil,  -- {row, col} when triggered
  bufnr = nil,
  timer = nil,
  enabled = true,
}

--- Cancel any pending operations
local function cancel_pending()
  -- Stop debounce timer
  if state.timer then
    vim.fn.timer_stop(state.timer)
    state.timer = nil
  end
  
  -- Cancel HTTP request
  client.cancel()
end

--- Reset state to idle
local function reset_state()
  cancel_pending()
  state.status = STATE.IDLE
  state.suggestion = ""
  state.cursor_pos = nil
  state.bufnr = nil
end

--- Check if we should trigger completion for this buffer
---@param bufnr number Buffer number
---@return boolean
function M.should_trigger(bufnr)
  if not state.enabled then
    return false
  end
  
  -- Check if we're in insert mode
  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "i" then
    return false
  end
  
  -- Check filetype
  local filetype = vim.bo[bufnr].filetype
  if not config.is_filetype_enabled(filetype) then
    return false
  end
  
  -- Don't trigger in command-line window
  local buftype = vim.bo[bufnr].buftype
  if buftype == "nofile" or buftype == "prompt" or buftype == "quickfix" then
    return false
  end
  
  return true
end

--- Perform the actual completion request
---@param bufnr number Buffer number
---@param cursor table Cursor position
local function do_trigger(bufnr, cursor)
  -- Double-check we should still trigger
  if not M.should_trigger(bufnr) then
    reset_state()
    return
  end
  
  -- Get current cursor position
  local current_cursor = vim.api.nvim_win_get_cursor(0)
  
  -- If cursor moved since we started, abort
  if cursor[1] ~= current_cursor[1] or cursor[2] ~= current_cursor[2] then
    reset_state()
    return
  end
  
  state.status = STATE.STREAMING
  state.suggestion = ""
  state.cursor_pos = cursor
  state.bufnr = bufnr
  
  -- Gather context and build prompt
  local prompt, ctx = context.get_prompt(bufnr, cursor)
  
  util.debug("Triggering completion, prefix length: %d, suffix length: %d",
    #ctx.prefix, #ctx.suffix)
  
  -- Make request
  client.generate(
    prompt,
    nil,
    -- on_token
    function(token)
      -- Check if we're still in the right state
      if state.status ~= STATE.STREAMING then
        return
      end
      
      -- Check if cursor is still in the same position
      local current = vim.api.nvim_win_get_cursor(0)
      if current[1] ~= state.cursor_pos[1] or current[2] ~= state.cursor_pos[2] then
        M.dismiss()
        return
      end
      
      -- Append token
      state.suggestion = state.suggestion .. token
      
      -- Show/update ghost text
      ghost.show(state.suggestion, state.bufnr, state.cursor_pos)
    end,
    -- on_complete
    function()
      if state.status == STATE.STREAMING then
        if state.suggestion ~= "" then
          state.status = STATE.SHOWING
          util.debug("Completion done, suggestion: %d chars", #state.suggestion)
        else
          reset_state()
        end
      end
    end,
    -- on_error
    function(err)
      util.debug("Completion error: %s", err)
      reset_state()
      ghost.clear()
    end
  )
end

--- Trigger completion (public interface)
---@param manual boolean|nil If true, trigger immediately without debounce
function M.trigger(manual)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  
  if not M.should_trigger(bufnr) then
    return
  end
  
  -- Cancel any existing pending operations
  cancel_pending()
  ghost.clear()
  
  local cfg = config.get()
  
  if manual then
    -- Trigger immediately
    state.status = STATE.PENDING
    state.bufnr = bufnr
    state.cursor_pos = cursor
    do_trigger(bufnr, cursor)
  else
    -- Debounced trigger
    state.status = STATE.PENDING
    state.bufnr = bufnr
    state.cursor_pos = cursor
    
    state.timer = vim.fn.timer_start(cfg.debounce_ms, function()
      state.timer = nil
      vim.schedule(function()
        do_trigger(bufnr, cursor)
      end)
    end)
  end
end

--- Accept the current suggestion
---@return boolean success
function M.accept()
  if state.status ~= STATE.SHOWING and state.status ~= STATE.STREAMING then
    return false
  end
  
  if state.suggestion == "" then
    return false
  end
  
  -- Get the suggestion text
  local text = state.suggestion
  
  -- Clear ghost text first
  ghost.clear()
  
  -- Reset state before scheduling to prevent double-accept
  reset_state()
  
  -- Schedule the buffer modification to avoid E565 error
  -- (Not allowed to change text or change window)
  vim.schedule(function()
    -- Insert the text at cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local col = cursor[2]
    
    -- Split text into lines
    local lines = vim.split(text, "\n", { plain = true })
    
    if #lines == 1 then
      -- Single line: insert at cursor
      local current_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
      local before = current_line:sub(1, col)
      local after = current_line:sub(col + 1)
      local new_line = before .. text .. after
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
      vim.api.nvim_win_set_cursor(0, { row, col + #text })
    else
      -- Multi-line: more complex insertion
      local current_line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
      local before = current_line:sub(1, col)
      local after = current_line:sub(col + 1)
      
      -- First line gets the text before cursor + first line of suggestion
      lines[1] = before .. lines[1]
      -- Last line gets the last line of suggestion + text after cursor
      lines[#lines] = lines[#lines] .. after
      
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
      
      -- Move cursor to end of inserted text
      local new_row = row + #lines - 1
      local new_col = #lines[#lines] - #after
      vim.api.nvim_win_set_cursor(0, { new_row, new_col })
    end
  end)
  
  return true
end

--- Dismiss the current suggestion
function M.dismiss()
  ghost.clear()
  reset_state()
end

--- Check if suggestion is visible
---@return boolean
function M.is_visible()
  return (state.status == STATE.SHOWING or state.status == STATE.STREAMING)
    and state.suggestion ~= ""
end

--- Get the current suggestion text
---@return string|nil
function M.get_suggestion()
  if M.is_visible() then
    return state.suggestion
  end
  return nil
end

--- Get the current state (for debugging)
---@return table
function M.get_state()
  return {
    status = state.status,
    suggestion_length = #state.suggestion,
    cursor_pos = state.cursor_pos,
    bufnr = state.bufnr,
    enabled = state.enabled,
  }
end

--- Enable completions
function M.enable()
  state.enabled = true
  util.info("Completions enabled")
end

--- Disable completions
function M.disable()
  M.dismiss()
  state.enabled = false
  util.info("Completions disabled")
end

--- Toggle completions
function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

--- Check if completions are enabled
---@return boolean
function M.is_enabled()
  return state.enabled
end

--- Handle cursor moved event
function M.on_cursor_moved()
  -- If we have a suggestion showing and cursor moved away, dismiss it
  if state.status == STATE.SHOWING or state.status == STATE.STREAMING then
    local cursor = vim.api.nvim_win_get_cursor(0)
    if state.cursor_pos and (cursor[1] ~= state.cursor_pos[1] or cursor[2] ~= state.cursor_pos[2]) then
      M.dismiss()
    end
  end
end

--- Handle insert leave event
function M.on_insert_leave()
  M.dismiss()
end

--- Handle text changed event
function M.on_text_changed()
  local cfg = config.get()
  if cfg.auto_trigger and state.enabled then
    M.trigger(false) -- debounced
  end
end

return M
