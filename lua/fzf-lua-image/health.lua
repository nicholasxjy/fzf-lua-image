local M = {}

function M.check()
  local health = vim.health
  health.start("fzf-lua-image")
  if vim.fn.has("nvim-0.10") == 1 then
    health.ok("Neovim >= 0.10")
  else
    health.error("Neovim >= 0.10 is required")
  end
  local integration = require("fzf-lua-image.integration")
  if integration.setup() then
    health.ok("fzf-lua image adapter installed")
  else
    health.error(integration.error)
  end
  local terminal = require("fzf-lua-image.terminal")
  if terminal.supported() then
    if terminal.env().supported then
      health.ok("Terminal supports Kitty graphics")
    else
      health.warn("Terminal support was forced with force=true")
    end
    health.info(terminal.env().placeholders and "Using Unicode placeholders" or "Using cursor placements")
    if terminal.env().placeholders and not vim.o.termguicolors then
      health.warn("Enable termguicolors for Unicode image placeholders")
    end
  else
    health.warn("Terminal is unsupported; use Kitty, Ghostty, or WezTerm")
  end
  if vim.fn.executable("magick") == 1 or (vim.fn.has("win32") == 0 and vim.fn.executable("convert") == 1) then
    health.ok("ImageMagick found")
  else
    health.warn("ImageMagick missing; only PNG previews are available")
  end
  health.info("Converted images: " .. require("fzf-lua-image.config").options.cache)
end

return M
