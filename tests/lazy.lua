-- Verify the recommended lazy.nvim dependency spec without network or Snacks.
local root = vim.fn.getcwd()
vim.go.loadplugins = true
assert(vim.env.FZF_LUA_PATH and vim.env.LAZY_NVIM_PATH, "set FZF_LUA_PATH and LAZY_NVIM_PATH")
vim.opt.runtimepath:prepend(vim.env.LAZY_NVIM_PATH)
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local success, err = xpcall(function()
  require("lazy").setup({
    {
      "ibhagwan/fzf-lua", dir = vim.env.FZF_LUA_PATH, cmd = "FzfLua",
      dependencies = { { "nicholasxjy/fzf-lua-image", dir = root } },
      opts = {},
    },
  }, {
    root = tmp .. "/plugins", lockfile = tmp .. "/lazy-lock.json",
    install = { missing = false }, checker = { enabled = false },
    change_detection = { enabled = false },
    readme = { enabled = false, root = tmp .. "/readme" }, pkg = { enabled = false, cache = tmp .. "/pkg-cache.lua" },
    state = tmp .. "/state.json",
    performance = { cache = { enabled = false }, rtp = { reset = false } },
  })
  assert(not package.loaded["fzf-lua"], "image plugin must not eagerly load a lazy fzf-lua")
  require("lazy").load({ plugins = { "fzf-lua" } })
  assert(package.loaded["fzf-lua"] and _G.FzfLua, "fzf-lua must finish loading")
  assert(require("fzf-lua-image.integration").setup())
  assert(vim.g.loaded_fzf_lua_image)
  assert(not _G.Snacks)
  print("PASS lazy: fzf-lua loads its image dependency automatically")
end, debug.traceback)
vim.fn.delete(tmp, "rf")
if not success then print(err) end
vim.cmd(success and "qa!" or "cquit 1")
