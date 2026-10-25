# fzf-lua-image

Standalone image previews for [fzf-lua](https://github.com/ibhagwan/fzf-lua),
extracted from [Snacks image](https://github.com/folke/snacks.nvim/blob/main/docs/image.md).
Loads automatically, with no `snacks.nvim` dependency or `setup()` required.

Supports image conversion, caching, tmux passthrough, SSH transfers, and cleanup
when switching files, hiding, resizing, or closing previews.

## Requirements

- Neovim **0.10+**, a recent fzf-lua, and fzf.
- **Kitty, Ghostty, or WezTerm**. Enable `termguicolors` for Unicode placeholders.
  Zellij is unsupported.
- **ImageMagick** (`magick`, or `convert` on Unix) for formats other than PNG.
  PDF and video previews require the appropriate delegates, such as Ghostscript and FFmpeg.

## Installation

### lazy.nvim

Add this plugin as an fzf-lua dependency:

```lua
{
  "ibhagwan/fzf-lua",
  dependencies = { "nicholasxjy/fzf-lua-image" },
  opts = {},
}
```

### vim.pack (Neovim 0.12+)

Add to your `init.lua`:

```lua
vim.pack.add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/nicholasxjy/fzf-lua-image" },
})
```

## Usage

Run `:FzfLua files`, `:FzfLua git_files`, or `:FzfLua oldfiles` and select an image.
Press `<F4>` if the preview is hidden. Animated images and videos show the first
frame; PDFs show the first page. Markdown inline images and document rendering
are outside this plugin's scope.

Use fzf-lua's `builtin` previewer (`winopts.preview.default = "builtin"`).
Configured `previewers.builtin.extensions` commands take priority.

Configuration is optional; see the [defaults](lua/fzf-lua-image/config.lua).
For example, to disable the extension:

```lua
require("fzf-lua-image").setup({ enabled = false })
```

Run `:checkhealth fzf-lua-image` to diagnose setup issues. Conversion errors
appear in the preview window.

## Testing

```sh
FZF_LUA_PATH=/absolute/path/to/fzf-lua make test
FZF_LUA_PATH=/absolute/path/to/fzf-lua \
  LAZY_NVIM_PATH=/absolute/path/to/lazy.nvim make test-lazy
```

## License

Original code: [MIT](LICENSE). Adapted Snacks code: [Apache-2.0](LICENSES/snacks.nvim.txt).
See [NOTICE](NOTICE) for attribution.
