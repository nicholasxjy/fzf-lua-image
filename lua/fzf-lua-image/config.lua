local M = {}

---@class fzf-lua-image.Config
local defaults = {
  enabled = true,
  formats = {
    "png", "jpg", "jpeg", "gif", "bmp", "webp", "tif", "tiff", "heic", "avif",
    "svg", "ico", "icns", "pdf", "mp4", "mov", "avi", "mkv", "webm",
  },
  cache = vim.fn.stdpath("cache") .. "/fzf-lua-image",
  force = false,
  terminal = {
    -- supported, placeholders, remote, cell_width and cell_height can be overridden.
  },
  convert = {
    -- Arguments are passed directly to ImageMagick, without a shell.
    magick = {
      default = { "{src}[0]", "-auto-orient", "-scale", "1920x1080>" },
      vector = { "-density", "192", "{src}[0]", "-scale", "1920x1080>" },
      pdf = { "-density", "192", "{src}[0]", "-background", "white", "-alpha", "remove", "-scale", "1920x1080>" },
    },
  },
}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  -- Lists must replace defaults, including an explicitly empty list.
  if opts and opts.formats then M.options.formats = vim.deepcopy(opts.formats) end
  return M.options
end

M.setup()
return M
