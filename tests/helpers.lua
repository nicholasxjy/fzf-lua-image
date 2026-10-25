local H = { cleanup_callbacks = {} }

function H.eq(expected, actual)
  assert(vim.deep_equal(expected, actual), "expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

function H.wait(fn)
  assert(vim.wait(5000, fn, 10), "timed out waiting for asynchronous work")
end

function H.magick()
  if vim.fn.executable("magick") == 1 then return "magick" end
  assert(vim.fn.executable("convert") == 1, "ImageMagick is required for conversion tests")
  return "convert"
end

function H.patch(tbl, key, value)
  local old = tbl[key]
  tbl[key] = value
  table.insert(H.cleanup_callbacks, 1, function() tbl[key] = old end)
end

function H.write(path, data)
  local file = assert(io.open(path, "wb"))
  file:write(data)
  file:close()
  return path
end

function H.png()
  local data = "iVBORw0KGgoAAAANSUhEUgAAAKAAAABQCAIAAAARP+ljAAAA1ElEQVR4nO3RAQkAIBDAwM9kJwPZ2BQijIMLMNisswmb7wU8ZXCcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEGxxkcZ3CcwXEXxTPTWBfKVmAAAAAASUVORK5CYII="
  return H.write(H.tmp .. "/preview.png", vim.base64.decode(data))
end

function H.reset()
  H.tmp = vim.fn.tempname()
  vim.fn.mkdir(H.tmp, "p")
  H.requests = {}
  H.patch(vim.api, "nvim_ui_send", function(data) table.insert(H.requests, data) end)
  for _, key in ipairs({ "TMUX", "ZELLIJ", "KITTY_WINDOW_ID", "GHOSTTY_RESOURCES_DIR", "SSH_CONNECTION", "SSH_CLIENT", "TERM_PROGRAM" }) do
    H.patch(vim.env, key, nil)
  end
  H.patch(vim.env, "TERM", "xterm-256color")
  local ok, config = pcall(require, "fzf-lua-image.config")
  if ok then
    config.setup({
      enabled = true,
      cache = H.tmp .. "/cache",
      terminal = { supported = true, placeholders = true, remote = false, cell_width = 8, cell_height = 16 },
    })
  end
end

function H.cleanup()
  local image = package.loaded["fzf-lua-image.image"]
  if image then image.clear() end
  for _, cb in ipairs(H.cleanup_callbacks) do cb() end
  H.cleanup_callbacks = {}
  vim.fn.delete(H.tmp, "rf")
end

function H.window()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor", row = 1, col = 2, width = 12, height = 4, style = "minimal", border = "single",
  })
  table.insert(H.cleanup_callbacks, 1, function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end)
  return buf, win
end

return H
