--- Configuration management for llama-cmp
local util = require("llama-cmp.util")

local M = {}

--- FIM token presets for popular models
M.presets = {
  codellama = {
    prefix = "<PRE>",
    suffix = "<SUF>",
    middle = "<MID>",
  },
  deepseek = {
    prefix = "<｜fim▁begin｜>",
    suffix = "<｜fim▁hole｜>",
    middle = "<｜fim▁end｜>",
  },
  starcoder = {
    prefix = "<fim_prefix>",
    suffix = "<fim_suffix>",
    middle = "<fim_middle>",
  },
  starcoder2 = {
    prefix = "<fim_prefix>",
    suffix = "<fim_suffix>",
    middle = "<fim_middle>",
  },
  qwen = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  qwen25coder = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  codegemma = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  codestral = {
    prefix = "[PREFIX]",
    suffix = "[SUFFIX]",
    middle = "[MIDDLE]",
  },
}

--- Default configuration
M.defaults = {
  -- Ollama settings
  endpoint = "http://localhost:11434",
  model = "qwen2.5-coder:1.5b",

  -- FIM tokens (fully configurable)
  fim = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },

  -- Behavior
  auto_trigger = true,
  debounce_ms = 300,

  -- Context settings
  context = {
    max_prefix_lines = 50,
    max_suffix_lines = 20,
    max_line_length = 500,
    lsp = {
      enabled = true,
      diagnostics = true,
      hover = true,
      signature_help = true,
      timeout_ms = 100,
      cache_ttl_ms = 500,
    },
  },

  -- Generation parameters
  generation = {
    max_tokens = 128,
    temperature = 0.2,
    stop = { "\n\n", "<|endoftext|>", "<|file_sep|>" },
  },

  -- Keymaps (set to false to disable individual keymaps)
  keymaps = {
    accept = "<Tab>",
    dismiss = "<C-]>",
    trigger = "<C-Space>",
  },

  -- Appearance
  highlight = "Comment",

  -- Filetypes
  filetypes = {
    enabled = { "*" },
    disabled = {
      "TelescopePrompt",
      "neo-tree",
      "NvimTree",
      "help",
      "dashboard",
      "alpha",
      "lazy",
      "mason",
      "notify",
      "toggleterm",
      "lazyterm",
      "noice",
      "",
    },
  },
}

--- Current active configuration
M.options = nil

--- Setup configuration with user options
---@param opts table|nil User configuration
function M.setup(opts)
  opts = opts or {}
  M.options = util.deep_merge(M.defaults, opts)
  
  -- Apply preset if specified
  if opts.preset and M.presets[opts.preset] then
    M.options.fim = util.deep_merge(M.presets[opts.preset], opts.fim or {})
  end
  
  return M.options
end

--- Get current configuration (initializes with defaults if not setup)
---@return table
function M.get()
  if not M.options then
    M.options = vim.deepcopy(M.defaults)
  end
  return M.options
end

--- Check if a filetype is enabled
---@param filetype string
---@return boolean
function M.is_filetype_enabled(filetype)
  local opts = M.get()
  
  -- Check disabled list first
  if util.list_contains(opts.filetypes.disabled, filetype) then
    return false
  end
  
  -- Check enabled list
  if util.list_contains(opts.filetypes.enabled, "*") then
    return true
  end
  
  return util.list_contains(opts.filetypes.enabled, filetype)
end

--- Apply a preset to the current configuration
---@param preset_name string Name of the preset
function M.apply_preset(preset_name)
  local preset = M.presets[preset_name]
  if preset then
    M.options.fim = util.deep_merge(preset, {})
    util.info("Applied preset: %s", preset_name)
  else
    util.warn("Unknown preset: %s", preset_name)
  end
end

return M
