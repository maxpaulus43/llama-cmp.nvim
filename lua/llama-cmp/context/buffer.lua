--- Buffer context extraction for llama-cmp
--- Extracts prefix (text before cursor) and suffix (text after cursor)
local config = require("llama-cmp.config")
local util = require("llama-cmp.util")

local M = {}

--- Get text before the cursor (prefix)
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col} (1-indexed row, 0-indexed col)
---@param max_lines number|nil Maximum lines to include
---@return string prefix text
function M.get_prefix(bufnr, cursor, max_lines)
  local opts = config.get()
  max_lines = max_lines or opts.context.max_prefix_lines
  local max_line_len = opts.context.max_line_length
  
  local row, col = cursor[1], cursor[2]
  
  -- Calculate start line
  local start_line = math.max(1, row - max_lines + 1)
  
  -- Get lines from start to current row
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, row, false)
  
  if #lines == 0 then
    return ""
  end
  
  -- Truncate lines that are too long
  for i, line in ipairs(lines) do
    if #line > max_line_len then
      lines[i] = util.truncate(line, max_line_len)
    end
  end
  
  -- Truncate the last line at cursor position
  local last_line = lines[#lines]
  if last_line then
    lines[#lines] = last_line:sub(1, col)
  end
  
  return table.concat(lines, "\n")
end

--- Get text after the cursor (suffix)
---@param bufnr number Buffer number
---@param cursor table Cursor position {row, col} (1-indexed row, 0-indexed col)
---@param max_lines number|nil Maximum lines to include
---@return string suffix text
function M.get_suffix(bufnr, cursor, max_lines)
  local opts = config.get()
  max_lines = max_lines or opts.context.max_suffix_lines
  local max_line_len = opts.context.max_line_length
  
  local row, col = cursor[1], cursor[2]
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  
  -- Calculate end line
  local end_line = math.min(line_count, row + max_lines - 1)
  
  -- Get lines from current row to end
  local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, end_line, false)
  
  if #lines == 0 then
    return ""
  end
  
  -- Truncate lines that are too long
  for i, line in ipairs(lines) do
    if #line > max_line_len then
      lines[i] = util.truncate(line, max_line_len)
    end
  end
  
  -- Truncate the first line after cursor position
  local first_line = lines[1]
  if first_line then
    lines[1] = first_line:sub(col + 1)
  end
  
  return table.concat(lines, "\n")
end

--- Get the current line content
---@param bufnr number Buffer number
---@param row number Row number (1-indexed)
---@return string
function M.get_line(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)
  return lines[1] or ""
end

--- Get file metadata for context
---@param bufnr number Buffer number
---@return table metadata
function M.get_metadata(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local filename = vim.fn.fnamemodify(filepath, ":t")
  
  return {
    filepath = filepath,
    filename = filename,
    filetype = filetype,
    language = filetype, -- alias
  }
end

--- Get indentation of current line
---@param bufnr number Buffer number
---@param row number Row number (1-indexed)
---@return string indentation (leading whitespace)
function M.get_indentation(bufnr, row)
  local line = M.get_line(bufnr, row)
  local indent = line:match("^(%s*)")
  return indent or ""
end

return M
