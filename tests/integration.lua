local H = require("tests.helpers")
local plugin = require("fzf-lua-image")
local config = require("fzf-lua-image.config")

return {
  { "automatically installs the adapter when the plugin file is sourced", function()
    assert(vim.env.FZF_LUA_PATH, "set FZF_LUA_PATH to an fzf-lua checkout")
    require("fzf-lua")
    local builtin = require("fzf-lua.previewer.builtin")
    local original = builtin.base.attach_snacks_image_buf
    vim.cmd("runtime plugin/fzf-lua-image.lua")
    assert(original ~= builtin.base.attach_snacks_image_buf)
    local patched = builtin.base.attach_snacks_image_buf
    plugin.setup()
    H.eq(patched, builtin.base.attach_snacks_image_buf)
  end },
  { "attaches images through the real fzf-lua previewer", function()
    local builtin = require("fzf-lua.previewer.builtin")
    local buf, win = H.window()
    local previewer = setmetatable({ snacks_image = { enabled = true }, win = { preview_winid = win } }, { __index = builtin.base })
    function previewer:set_preview_buf(newbuf, minimal)
      H.eq(true, minimal)
      vim.api.nvim_win_set_buf(win, newbuf)
      self.preview_bufnr = newbuf
    end
    local entry = { path = H.png() }
    H.eq(true, previewer:attach_snacks_image_buf(buf, entry))
    H.wait(function() return vim.b[buf].fzf_lua_image == true end)
    H.eq(true, entry.no_scrollbar)
    H.eq(true, entry.do_not_cache)
    H.eq(0, vim.wo[win].winblend)
  end },
  { "retains text previews and respects the fzf-lua image opt-out", function()
    local builtin = require("fzf-lua.previewer.builtin")
    local previewer = setmetatable({ snacks_image = { enabled = true } }, { __index = builtin.base })
    H.eq(false, previewer:attach_snacks_image_buf(0, { path = H.tmp .. "/file.lua" }))
    previewer.snacks_image.enabled = false
    H.eq(false, previewer:attach_snacks_image_buf(0, { path = H.png() }))
    config.options.enabled = false
    previewer.snacks_image.enabled = true
    H.eq(false, previewer:attach_snacks_image_buf(0, { path = H.png() }))
  end },
  { "keeps unsupported terminals on the normal preview path", function()
    local builtin = require("fzf-lua.previewer.builtin")
    config.options.terminal.supported = false
    local previewer = setmetatable({ snacks_image = { enabled = true } }, { __index = builtin.base })
    H.eq(false, previewer:attach_snacks_image_buf(0, { path = H.png() }))
  end },
  { "replaces configured formats, including an empty list", function()
    plugin.setup({ formats = { "png" } })
    H.eq(true, plugin.supports_file("photo.PNG"))
    H.eq(false, plugin.supports_file("photo.jpg"))
    plugin.setup({ formats = {} })
    H.eq(false, plugin.supports_file("photo.png"))
  end },
}
