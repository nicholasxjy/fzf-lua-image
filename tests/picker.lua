-- Exercise the real fzf process, RPC preview callbacks and Neovim windows.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
assert(vim.env.FZF_LUA_PATH, "set FZF_LUA_PATH to an fzf-lua checkout")
vim.opt.runtimepath:append(vim.env.FZF_LUA_PATH)
vim.o.columns, vim.o.lines = 100, 32
vim.cmd("filetype on")

local H = require("tests.helpers")
H.reset()
local success, err = xpcall(function()
  local fzf = require("fzf-lua")
  vim.cmd("runtime plugin/fzf-lua-image.lua")
  fzf.setup({ winopts = { preview = { layout = "horizontal" } } })
  local png = H.png()
  assert(vim.system({ H.magick(), png, "-resize", "640x320!", png }):wait().code == 0)
  local text = H.write(H.tmp .. "/text.lua", "return 42\n")
  local jpg = H.tmp .. "/photo with spaces.jpg"
  assert(vim.system({ H.magick(), png, jpg }):wait().code == 0)
  fzf.files({
    cwd = H.tmp,
    cmd = "find . -type f",
    file_icons = false, git_icons = false,
    fzf_opts = { ["--no-sort"] = true, ["--layout"] = "reverse" },
  })
  local win
  H.wait(function()
    win = require("fzf-lua.win").__SELF()
    return win and win._previewer and win._previewer.loaded_entry
  end)
  local function selected(path)
    H.wait(function()
      local entry = win._previewer.loaded_entry
      return entry and (vim.uv or vim.loop).fs_realpath(entry.path) == (vim.uv or vim.loop).fs_realpath(path)
    end)
  end
  local function rendered()
    H.wait(function()
      local buf = win._previewer.preview_bufnr
      return buf and vim.api.nvim_buf_is_valid(buf)
        and #vim.api.nvim_buf_get_extmarks(buf, require("fzf-lua-image.image").ns, 0, -1, {}) > 0
    end)
  end
  local function send(keys)
    vim.api.nvim_chan_send(vim.bo[win.fzf_bufnr].channel, keys)
  end
  send("\21preview.png")
  selected(png)
  rendered()
  print("PASS picker: automatic PNG preview without Snacks")
  H.requests = {}
  send("\21text.lua")
  selected(text)
  H.eq({ "return 42" }, vim.api.nvim_buf_get_lines(win._previewer.preview_bufnr, 0, -1, false))
  assert(table.concat(H.requests):find("d=I", 1, true), "image data must be freed on selection change")
  print("PASS picker: text preview and image cleanup on selection change")
  send("\21photo")
  selected(jpg)
  rendered()
  print("PASS picker: JPEG conversion with spaces in the path")
  win:toggle_preview()
  H.wait(function() return not win.preview_winid or not vim.api.nvim_win_is_valid(win.preview_winid) end)
  win:toggle_preview()
  rendered()
  print("PASS picker: hide and reopen preview")
  H.requests = {}
  vim.o.columns = 70
  vim.api.nvim_exec_autocmds("VimResized", {})
  rendered()
  H.wait(function() return table.concat(H.requests):find("a=p", 1, true) end)
  print("PASS picker: preview resize")
  H.requests = {}
  win:close()
  H.wait(function() return table.concat(H.requests):find("d=I", 1, true) end)
  H.eq(nil, _G.Snacks)
  print("PASS picker: close frees terminal images")
end, debug.traceback)
local win = package.loaded["fzf-lua.win"] and require("fzf-lua.win").__SELF()
if not success then
  print(err)
  if win then
    print("loaded entry", vim.inspect(win._previewer and win._previewer.loaded_entry))
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      print(vim.api.nvim_buf_get_name(buf), vim.inspect(vim.api.nvim_buf_get_lines(buf, 0, 12, false)))
    end
  end
end
if win then pcall(function() win:close() end) end
H.cleanup()
vim.cmd(success and "qa!" or "cquit 1")
