-- Source the plugin before fzf-lua's main module, as a native package loader can.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
assert(vim.env.FZF_LUA_PATH, "set FZF_LUA_PATH to an fzf-lua checkout")
vim.opt.runtimepath:append(vim.env.FZF_LUA_PATH)

local success, err = xpcall(function()
  assert(not package.loaded["fzf-lua"])
  vim.cmd("runtime plugin/fzf-lua-image.lua")
  assert(require("fzf-lua-image.integration").setup())
  require("fzf-lua").setup()
  assert(not _G.Snacks)
  assert(not package.loaded["snacks"])
  print("PASS startup: image plugin loads before fzf-lua")
end, debug.traceback)
if not success then print(err) end
vim.cmd(success and "qa!" or "cquit 1")
