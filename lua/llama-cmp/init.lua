--- llama-cmp.nvim
--- Local Copilot-style completions using Ollama with FIM models
---
--- Usage:
---   require('llama-cmp').setup({
---     model = "qwen2.5-coder:1.5b",
---     -- see config.lua for all options
---   })

local M = {}

--- Module version
M.version = "0.1.0"

--- Autocommand group
local augroup = nil

--- Check if setup has been called
local is_setup = false

--- Setup the plugin
---@param opts table|nil Configuration options
function M.setup(opts)
  -- Load modules
  local config = require("llama-cmp.config")
  local completion = require("llama-cmp.completion")
  local keymaps = require("llama-cmp.keymaps")
  
  -- Validate Neovim version
  if vim.fn.has("nvim-0.9.0") ~= 1 then
    vim.notify("[llama-cmp] Neovim 0.9.0+ is required", vim.log.levels.ERROR)
    return
  end
  
  -- Apply configuration
  config.setup(opts)
  
  -- Setup keymaps
  keymaps.setup()
  
  -- Create autocommand group
  if augroup then
    vim.api.nvim_del_augroup_by_id(augroup)
  end
  augroup = vim.api.nvim_create_augroup("LlamaCmp", { clear = true })
  
  -- Auto-trigger on text change
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = augroup,
    callback = function()
      completion.on_text_changed()
    end,
    desc = "llama-cmp: Trigger on text change",
  })
  
  -- Dismiss on cursor move
  vim.api.nvim_create_autocmd("CursorMovedI", {
    group = augroup,
    callback = function()
      completion.on_cursor_moved()
    end,
    desc = "llama-cmp: Handle cursor movement",
  })
  
  -- Dismiss on insert leave
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function()
      completion.on_insert_leave()
    end,
    desc = "llama-cmp: Cleanup on insert leave",
  })
  
  -- Dismiss on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    callback = function()
      completion.dismiss()
    end,
    desc = "llama-cmp: Cleanup on buffer leave",
  })
  
  is_setup = true
end

--- Check if plugin is setup
---@return boolean
function M.is_setup()
  return is_setup
end

--- Trigger completion manually
function M.trigger()
  if not is_setup then
    vim.notify("[llama-cmp] Plugin not setup. Call require('llama-cmp').setup() first.", vim.log.levels.WARN)
    return
  end
  require("llama-cmp.completion").trigger(true)
end

--- Accept the current suggestion
---@return boolean success
function M.accept()
  return require("llama-cmp.completion").accept()
end

--- Dismiss the current suggestion
function M.dismiss()
  require("llama-cmp.completion").dismiss()
end

--- Check if suggestion is visible
---@return boolean
function M.is_visible()
  return require("llama-cmp.completion").is_visible()
end

--- Get the current suggestion text
---@return string|nil
function M.get_suggestion()
  return require("llama-cmp.completion").get_suggestion()
end

--- Enable completions
function M.enable()
  require("llama-cmp.completion").enable()
end

--- Disable completions
function M.disable()
  require("llama-cmp.completion").disable()
end

--- Toggle completions
function M.toggle()
  require("llama-cmp.completion").toggle()
end

--- Check if completions are enabled
---@return boolean
function M.is_enabled()
  return require("llama-cmp.completion").is_enabled()
end

--- Apply a FIM preset
---@param preset_name string Name of the preset (codellama, deepseek, starcoder, qwen, etc.)
function M.apply_preset(preset_name)
  require("llama-cmp.config").apply_preset(preset_name)
end

--- Get available presets
---@return table presets
function M.get_presets()
  return require("llama-cmp.config").presets
end

--- Get current configuration
---@return table config
function M.get_config()
  return require("llama-cmp.config").get()
end

--- Get completion state (for debugging)
---@return table state
function M.get_state()
  return require("llama-cmp.completion").get_state()
end

--- List available models from Ollama
---@param callback function Callback: function(models: table|nil, err: string|nil)
function M.list_models(callback)
  require("llama-cmp.client").list_models(callback)
end

--- Check Ollama health
---@param callback function Callback: function(ok: boolean, err: string|nil)
function M.health_check(callback)
  require("llama-cmp.client").health_check(callback)
end

return M
