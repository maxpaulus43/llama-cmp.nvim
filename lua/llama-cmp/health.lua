--- Health check for llama-cmp
--- Run with :checkhealth llama-cmp
local M = {}

function M.check()
  vim.health.start("llama-cmp.nvim")
  
  -- Check Neovim version
  if vim.fn.has("nvim-0.9.0") == 1 then
    vim.health.ok("Neovim version >= 0.9.0")
  else
    vim.health.error("Neovim 0.9.0+ is required", {
      "Upgrade to Neovim 0.9.0 or later",
    })
  end
  
  -- Check if curl is available
  if vim.fn.executable("curl") == 1 then
    vim.health.ok("curl is installed")
  else
    vim.health.error("curl is not installed", {
      "Install curl to make HTTP requests to Ollama",
    })
  end
  
  -- Check if plugin is setup
  local llama_cmp = require("llama-cmp")
  if llama_cmp.is_setup() then
    vim.health.ok("Plugin is setup")
  else
    vim.health.warn("Plugin is not setup", {
      "Call require('llama-cmp').setup() in your config",
    })
  end
  
  -- Check configuration
  local config = require("llama-cmp.config")
  local cfg = config.get()
  vim.health.info("Endpoint: " .. cfg.endpoint)
  vim.health.info("Model: " .. cfg.model)
  vim.health.info("Auto-trigger: " .. tostring(cfg.auto_trigger))
  vim.health.info("Debounce: " .. cfg.debounce_ms .. "ms")
  
  -- Check Ollama connection
  vim.health.info("Checking Ollama connection...")
  
  local client = require("llama-cmp.client")
  
  -- We need to do this synchronously for health check
  local check_done = false
  local check_ok = false
  local check_err = nil
  
  client.health_check(function(ok, err)
    check_ok = ok
    check_err = err
    check_done = true
  end)
  
  -- Wait for check to complete (with timeout)
  local timeout = 50 -- 5 seconds
  while not check_done and timeout > 0 do
    vim.wait(100)
    timeout = timeout - 1
  end
  
  if not check_done then
    vim.health.error("Ollama health check timed out", {
      "Check if Ollama is running at " .. cfg.endpoint,
      "Try: ollama serve",
    })
  elseif check_ok then
    vim.health.ok("Ollama is accessible at " .. cfg.endpoint)
    
    -- List models
    local models_done = false
    local models = nil
    
    client.list_models(function(m, err)
      models = m
      models_done = true
    end)
    
    timeout = 30
    while not models_done and timeout > 0 do
      vim.wait(100)
      timeout = timeout - 1
    end
    
    if models and #models > 0 then
      vim.health.ok("Found " .. #models .. " models")
      
      -- Check if configured model exists
      local model_found = false
      for _, m in ipairs(models) do
        if m == cfg.model or m:match("^" .. cfg.model:gsub("%-", "%%-")) then
          model_found = true
          break
        end
      end
      
      if model_found then
        vim.health.ok("Configured model '" .. cfg.model .. "' is available")
      else
        vim.health.warn("Configured model '" .. cfg.model .. "' not found", {
          "Available models: " .. table.concat(models, ", "),
          "Run: ollama pull " .. cfg.model,
        })
      end
    else
      vim.health.warn("No models found or failed to list models", {
        "Pull a model: ollama pull qwen2.5-coder:1.5b",
      })
    end
  else
    vim.health.error("Cannot connect to Ollama: " .. (check_err or "unknown error"), {
      "Check if Ollama is running",
      "Try: ollama serve",
      "Check endpoint: " .. cfg.endpoint,
    })
  end
  
  -- Check FIM configuration
  vim.health.info("FIM tokens configured:")
  vim.health.info("  Prefix: " .. cfg.fim.prefix)
  vim.health.info("  Suffix: " .. cfg.fim.suffix)
  vim.health.info("  Middle: " .. cfg.fim.middle)
  
  -- Check keymaps
  local keymaps = cfg.keymaps
  if keymaps.accept then
    vim.health.info("Accept keymap: " .. keymaps.accept)
  end
  if keymaps.dismiss then
    vim.health.info("Dismiss keymap: " .. keymaps.dismiss)
  end
  if keymaps.trigger then
    vim.health.info("Trigger keymap: " .. keymaps.trigger)
  end
end

return M
