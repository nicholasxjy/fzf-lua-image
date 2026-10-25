local M = {}
local installed = false

---Use the same attachment hook as fzf-lua's native Snacks support.
---Do not create a Snacks global or replace the user's previewer configuration.
function M.setup()
  if installed then return true end
  local ok, builtin = pcall(require, "fzf-lua.previewer.builtin")
  if not ok then
    M.error = "fzf-lua is unavailable: " .. tostring(builtin)
    return false
  end
  local original = builtin.base.attach_snacks_image_buf
  if type(original) ~= "function" then
    M.error = "This fzf-lua version has no image attachment hook. Update ibhagwan/fzf-lua."
    return false
  end
  -- fzf-lua switches buffers with eventignore=all. A bufhidden=wipe buffer can
  -- disappear there without firing BufDelete/BufWipeout, so clean it explicitly.
  local set_preview_buf = builtin.base.set_preview_buf
  builtin.base.set_preview_buf = function(self, buf, ...)
    local image = package.loaded["fzf-lua-image.image"]
    if image and self.preview_bufnr and self.preview_bufnr ~= buf then image.clear(self.preview_bufnr) end
    return set_preview_buf(self, buf, ...)
  end
  local clear_preview_buf = builtin.base.clear_preview_buf
  builtin.base.clear_preview_buf = function(self, ...)
    local image = package.loaded["fzf-lua-image.image"]
    if image and self.preview_bufnr then image.clear(self.preview_bufnr) end
    return clear_preview_buf(self, ...)
  end
  builtin.base.attach_snacks_image_buf = function(self, buf, entry)
    local plugin = require("fzf-lua-image")
    if (self.snacks_image or {}).enabled == false or not plugin.supports(entry.path) then
      return original(self, buf, entry)
    end
    entry.no_scrollbar = true
    -- Converted PNG files are cached on disk. Keeping hidden preview buffers
    -- alive would also keep their terminal graphics and autocmds alive.
    entry.do_not_cache = true
    self.clear_on_redraw = true
    self:set_preview_buf(buf, true)
    require("fzf-lua-image.image").attach(buf, { src = entry.path, win = self.win.preview_winid })
    return true
  end
  installed = true
  M.error = nil
  return true
end

return M
