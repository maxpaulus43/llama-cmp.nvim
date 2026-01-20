# llama-cmp.nvim

Local Copilot-style code completions for Neovim using [Ollama](https://ollama.ai) with Fill-in-the-Middle (FIM) models.

![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-green?logo=neovim)
![Lua](https://img.shields.io/badge/Lua-blue?logo=lua)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- **Local & Private** - All completions run on your machine via Ollama
- **Streaming** - Ghost text updates in real-time as tokens arrive
- **Multi-line** - Full support for multi-line completions
- **LSP Context** - Sends type info, signatures, and diagnostics to the model
- **FIM Support** - Pre-configured for popular code models (CodeLlama, Qwen, DeepSeek, StarCoder, etc.)
- **Zero Dependencies** - No external Lua dependencies, just `curl`
- **Async & Debounced** - Non-blocking with configurable debounce

## Requirements

- Neovim >= 0.9.0
- [Ollama](https://ollama.ai) running locally
- `curl` (usually pre-installed)
- A FIM-capable model (see [Recommended Models](#recommended-models))

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/llama-cmp.nvim",
  event = "InsertEnter",
  config = function()
    require("llama-cmp").setup({
      model = "qwen2.5-coder:1.5b",
    })
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/llama-cmp.nvim",
  config = function()
    require("llama-cmp").setup({
      model = "qwen2.5-coder:1.5b",
    })
  end,
}
```

### Manual

Clone to your Neovim packages directory:

```bash
git clone https://github.com/yourusername/llama-cmp.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/llama-cmp.nvim
```

## Quick Start

1. **Install and start Ollama:**

   ```bash
   # macOS
   brew install ollama
   
   # Or download from https://ollama.ai
   
   # Start the server
   ollama serve
   ```

2. **Pull a FIM model:**

   ```bash
   ollama pull qwen2.5-coder:1.5b
   ```

3. **Add to your Neovim config:**

   ```lua
   require("llama-cmp").setup({
     model = "qwen2.5-coder:1.5b",
   })
   ```

4. **Start typing!** Completions will appear as ghost text after a short delay.

## Keymaps

| Key | Action |
|-----|--------|
| `<Tab>` | Accept suggestion |
| `<C-]>` | Dismiss suggestion |
| `<C-Space>` | Manually trigger completion |

All keymaps are configurable. Tab falls back to normal behavior when no suggestion is visible.

## Configuration

```lua
require("llama-cmp").setup({
  -- Ollama settings
  endpoint = "http://localhost:11434",
  model = "qwen2.5-coder:1.5b",

  -- FIM tokens (or use `preset` option below)
  fim = {
    prefix = "<|fim_prefix|>",
    suffix = "<|fim_suffix|>",
    middle = "<|fim_middle|>",
  },
  
  -- Use a preset instead of manual FIM tokens
  -- preset = "qwen",  -- codellama, deepseek, starcoder, qwen, codegemma, codestral

  -- Behavior
  auto_trigger = true,       -- Trigger on typing
  debounce_ms = 300,         -- Debounce delay

  -- Context sent to model
  context = {
    max_prefix_lines = 50,   -- Lines before cursor
    max_suffix_lines = 20,   -- Lines after cursor
    max_line_length = 500,   -- Truncate long lines
    lsp = {
      enabled = true,        -- Include LSP context
      diagnostics = true,    -- Include diagnostics
      hover = true,          -- Include type info
      signature_help = true, -- Include signature help
      timeout_ms = 100,      -- LSP request timeout
      cache_ttl_ms = 500,    -- Cache duration
    },
  },

  -- Generation parameters
  generation = {
    max_tokens = 128,
    temperature = 0.2,
    stop = { "\n\n", "<|endoftext|>" },
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    accept = "<Tab>",
    dismiss = "<C-]>",
    trigger = "<C-Space>",
  },

  -- Ghost text appearance
  highlight = "Comment",  -- Highlight group for suggestions

  -- Filetypes
  filetypes = {
    enabled = { "*" },    -- Enable for all filetypes
    disabled = {          -- Except these
      "TelescopePrompt",
      "neo-tree",
      "NvimTree",
      "help",
    },
  },
})
```

## FIM Presets

Use the `preset` option to automatically configure FIM tokens for your model:

```lua
require("llama-cmp").setup({
  model = "codellama:7b-code",
  preset = "codellama",
})
```

| Preset | Models |
|--------|--------|
| `codellama` | CodeLlama, Code Llama |
| `deepseek` | DeepSeek Coder |
| `starcoder` | StarCoder, StarCoder2 |
| `qwen` | Qwen 2.5 Coder |
| `codegemma` | CodeGemma |
| `codestral` | Codestral |

Or configure tokens manually via the `fim` option.

## Commands

| Command | Description |
|---------|-------------|
| `:LlamaCmp enable` | Enable completions |
| `:LlamaCmp disable` | Disable completions |
| `:LlamaCmp toggle` | Toggle on/off |
| `:LlamaCmp trigger` | Manually trigger completion |
| `:LlamaCmp dismiss` | Dismiss current suggestion |
| `:LlamaCmp status` | Show current status |
| `:LlamaCmp models` | List available Ollama models |
| `:LlamaCmp preset [name]` | List or apply a FIM preset |
| `:LlamaCmp health` | Run health check |

## Lua API

```lua
local llama = require("llama-cmp")

llama.trigger()        -- Trigger completion
llama.accept()         -- Accept suggestion
llama.dismiss()        -- Dismiss suggestion
llama.is_visible()     -- Check if suggestion showing
llama.get_suggestion() -- Get current suggestion text

llama.enable()         -- Enable completions
llama.disable()        -- Disable completions
llama.toggle()         -- Toggle on/off
llama.is_enabled()     -- Check if enabled

llama.apply_preset("qwen")  -- Apply a FIM preset
llama.get_presets()         -- Get all presets
llama.get_config()          -- Get current config
```

## Recommended Models

| Model | Size | Quality | Speed | Command |
|-------|------|---------|-------|---------|
| `qwen2.5-coder:1.5b` | 1.5B | Good | Fast | `ollama pull qwen2.5-coder:1.5b` |
| `qwen2.5-coder:7b` | 7B | Great | Medium | `ollama pull qwen2.5-coder:7b` |
| `codellama:7b-code` | 7B | Great | Medium | `ollama pull codellama:7b-code` |
| `deepseek-coder:6.7b` | 6.7B | Great | Medium | `ollama pull deepseek-coder:6.7b` |
| `starcoder2:3b` | 3B | Good | Fast | `ollama pull starcoder2:3b` |
| `codegemma:7b` | 7B | Great | Medium | `ollama pull codegemma:7b` |

For the best experience, use a model that fits in your GPU memory. Smaller models (1.5B-3B) are faster but less accurate; larger models (7B+) are more accurate but slower.

## Health Check

Run `:checkhealth llama-cmp` to verify your setup:

```
llama-cmp.nvim
- OK Neovim version >= 0.9.0
- OK curl is installed
- OK Plugin is setup
- OK Ollama is accessible at http://localhost:11434
- OK Found 5 models
- OK Configured model 'qwen2.5-coder:1.5b' is available
```

## Troubleshooting

### Completions not appearing

1. Check Ollama is running: `curl http://localhost:11434/api/tags`
2. Check model is pulled: `ollama list`
3. Run `:checkhealth llama-cmp`
4. Enable debug logging: `vim.g.llama_cmp_debug = true`

### Slow completions

- Use a smaller model (1.5B-3B)
- Reduce `max_prefix_lines` and `max_suffix_lines`
- Reduce `max_tokens`
- Ensure Ollama is using GPU: `ollama run qwen2.5-coder:1.5b` and check output

### Tab key conflicts

If Tab doesn't work correctly with other plugins:

```lua
require("llama-cmp").setup({
  keymaps = {
    accept = "<C-y>",  -- Use a different key
  },
})
```

### Wrong FIM tokens

Different models use different FIM token formats. Use the `preset` option or configure `fim` manually:

```lua
require("llama-cmp").setup({
  model = "deepseek-coder:6.7b",
  preset = "deepseek",  -- Automatically sets correct tokens
})
```

## How It Works

1. **On typing**, the plugin debounces and gathers context:
   - Text before cursor (prefix)
   - Text after cursor (suffix)
   - LSP info (types, signatures, diagnostics)

2. **Builds a FIM prompt** in the format the model expects:
   ```
   <|fim_prefix|>{prefix}<|fim_suffix|>{suffix}<|fim_middle|>
   ```

3. **Streams the response** from Ollama, updating ghost text as tokens arrive

4. **On Tab**, inserts the suggestion and moves cursor to the end

## Contributing

Contributions are welcome! Please open an issue or PR.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Ollama](https://ollama.ai) for making local LLMs easy
- [copilot.lua](https://github.com/zbirenbaum/copilot.lua) for inspiration on ghost text rendering
- The Neovim community
