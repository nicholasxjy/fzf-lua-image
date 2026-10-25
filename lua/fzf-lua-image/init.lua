local M = {}
local config = require("fzf-lua-image.config")

function M.setup(opts)
  if opts then config.setup(vim.tbl_deep_extend("force", config.options, opts)) end
  require("fzf-lua-image.integration").setup()
  return M
end

function M.supports_file(file)
  if type(file) ~= "string" then return false end
  return vim.tbl_contains(config.options.formats, vim.fn.fnamemodify(file, ":e"):lower())
end

function M.supports(file)
  return config.options.enabled and M.supports_file(file) and require("fzf-lua-image.terminal").supported()
end

return M
