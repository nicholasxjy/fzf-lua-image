if vim.g.loaded_fzf_lua_image then return end
vim.g.loaded_fzf_lua_image = true

require("fzf-lua-image").setup()
