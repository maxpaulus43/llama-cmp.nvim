--- llama-cmp.nvim plugin loader
--- Defines user commands and integrates with Neovim

-- Prevent loading twice
if vim.g.loaded_llama_cmp then
  return
end
vim.g.loaded_llama_cmp = true

-- Check Neovim version
if vim.fn.has("nvim-0.9.0") ~= 1 then
  vim.api.nvim_echo({
    { "[llama-cmp] ", "ErrorMsg" },
    { "Neovim 0.9.0+ is required", "WarningMsg" },
  }, true, {})
  return
end

-- User commands
vim.api.nvim_create_user_command("LlamaCmp", function(opts)
  local args = opts.fargs
  local cmd = args[1]
  
  if cmd == "enable" then
    require("llama-cmp").enable()
  elseif cmd == "disable" then
    require("llama-cmp").disable()
  elseif cmd == "toggle" then
    require("llama-cmp").toggle()
  elseif cmd == "trigger" then
    require("llama-cmp").trigger()
  elseif cmd == "dismiss" then
    require("llama-cmp").dismiss()
  elseif cmd == "status" then
    local llama = require("llama-cmp")
    local state = llama.get_state()
    local config = llama.get_config()
    print(string.format(
      "[llama-cmp] enabled=%s status=%s model=%s",
      state.enabled,
      state.status,
      config.model
    ))
  elseif cmd == "models" then
    require("llama-cmp").list_models(function(models, err)
      if err then
        vim.notify("[llama-cmp] " .. err, vim.log.levels.ERROR)
      elseif models then
        vim.notify("[llama-cmp] Available models:\n" .. table.concat(models, "\n"), vim.log.levels.INFO)
      end
    end)
  elseif cmd == "preset" then
    local preset = args[2]
    if preset then
      require("llama-cmp").apply_preset(preset)
    else
      local presets = require("llama-cmp").get_presets()
      local names = {}
      for name, _ in pairs(presets) do
        table.insert(names, name)
      end
      table.sort(names)
      vim.notify("[llama-cmp] Available presets: " .. table.concat(names, ", "), vim.log.levels.INFO)
    end
  elseif cmd == "health" then
    vim.cmd("checkhealth llama-cmp")
  else
    -- Show help
    print([[
llama-cmp.nvim commands:
  :LlamaCmp enable    - Enable completions
  :LlamaCmp disable   - Disable completions
  :LlamaCmp toggle    - Toggle completions
  :LlamaCmp trigger   - Trigger completion manually
  :LlamaCmp dismiss   - Dismiss current suggestion
  :LlamaCmp status    - Show current status
  :LlamaCmp models    - List available Ollama models
  :LlamaCmp preset    - List or apply FIM presets
  :LlamaCmp health    - Run health check
]])
  end
end, {
  nargs = "*",
  complete = function(arglead, cmdline, cursorpos)
    local args = vim.split(cmdline, "%s+")
    if #args == 2 then
      -- First argument: subcommand
      local commands = { "enable", "disable", "toggle", "trigger", "dismiss", "status", "models", "preset", "health" }
      return vim.tbl_filter(function(cmd)
        return cmd:find(arglead, 1, true) == 1
      end, commands)
    elseif #args == 3 and args[2] == "preset" then
      -- Second argument for preset: preset names
      local presets = require("llama-cmp.config").presets
      local names = {}
      for name, _ in pairs(presets) do
        if name:find(arglead, 1, true) == 1 then
          table.insert(names, name)
        end
      end
      return names
    end
    return {}
  end,
  desc = "llama-cmp.nvim commands",
})

-- Create highlight group with default styling
vim.api.nvim_set_hl(0, "LlamaCmpGhost", { link = "Comment", default = true })
