--- Keymap management for llama-cmp
--- Sets up keymaps with proper fallback behavior
local config = require("llama-cmp.config")
local completion = require("llama-cmp.completion")

local M = {}

--- Store original mappings for restoration
local original_mappings = {}

--- Get the RHS of an existing mapping
---@param mode string Mode
---@param lhs string Left-hand side
---@return table|nil mapping info
local function get_existing_mapping(mode, lhs)
  local mappings = vim.api.nvim_get_keymap(mode)
  for _, map in ipairs(mappings) do
    if map.lhs == lhs then
      return map
    end
  end
  return nil
end

--- Create a fallback function for Tab key
---@return string
local function tab_fallback()
  -- Check for other completion plugins
  -- nvim-cmp
  local ok, cmp = pcall(require, "cmp")
  if ok and cmp.visible() then
    return vim.api.nvim_replace_termcodes("<C-n>", true, true, true)
  end
  
  -- Default: insert a tab character or trigger default tab behavior
  return vim.api.nvim_replace_termcodes("<Tab>", true, true, true)
end

--- Setup keymaps
function M.setup()
  local cfg = config.get()
  local keymaps = cfg.keymaps
  
  if not keymaps then
    return
  end
  
  -- Accept keymap (Tab)
  if keymaps.accept and keymaps.accept ~= false then
    local lhs = keymaps.accept
    
    -- Store original mapping
    original_mappings[lhs] = get_existing_mapping("i", lhs)
    
    vim.keymap.set("i", lhs, function()
      if completion.is_visible() then
        completion.accept()
        return ""
      else
        -- Fallback to original behavior
        local orig = original_mappings[lhs]
        if orig and orig.callback then
          return orig.callback()
        elseif orig and orig.rhs then
          return vim.api.nvim_replace_termcodes(orig.rhs, true, true, true)
        else
          return tab_fallback()
        end
      end
    end, {
      expr = true,
      noremap = true,
      silent = true,
      desc = "llama-cmp: Accept suggestion or fallback",
    })
  end
  
  -- Dismiss keymap
  if keymaps.dismiss and keymaps.dismiss ~= false then
    vim.keymap.set("i", keymaps.dismiss, function()
      if completion.is_visible() then
        completion.dismiss()
        return ""
      end
      -- Let the key pass through
      return vim.api.nvim_replace_termcodes(keymaps.dismiss, true, true, true)
    end, {
      expr = true,
      noremap = true,
      silent = true,
      desc = "llama-cmp: Dismiss suggestion",
    })
  end
  
  -- Manual trigger keymap
  if keymaps.trigger and keymaps.trigger ~= false then
    vim.keymap.set("i", keymaps.trigger, function()
      completion.trigger(true) -- manual trigger
    end, {
      noremap = true,
      silent = true,
      desc = "llama-cmp: Trigger completion",
    })
  end
end

--- Remove keymaps
function M.teardown()
  local cfg = config.get()
  local keymaps = cfg.keymaps
  
  if not keymaps then
    return
  end
  
  -- Remove accept keymap and restore original
  if keymaps.accept then
    pcall(vim.keymap.del, "i", keymaps.accept)
    
    local orig = original_mappings[keymaps.accept]
    if orig then
      if orig.callback then
        vim.keymap.set("i", keymaps.accept, orig.callback, {
          expr = orig.expr == 1,
          noremap = orig.noremap == 1,
          silent = orig.silent == 1,
        })
      elseif orig.rhs then
        vim.keymap.set("i", keymaps.accept, orig.rhs, {
          expr = orig.expr == 1,
          noremap = orig.noremap == 1,
          silent = orig.silent == 1,
        })
      end
    end
  end
  
  -- Remove other keymaps
  if keymaps.dismiss then
    pcall(vim.keymap.del, "i", keymaps.dismiss)
  end
  
  if keymaps.trigger then
    pcall(vim.keymap.del, "i", keymaps.trigger)
  end
  
  original_mappings = {}
end

return M
