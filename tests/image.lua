local H = require("tests.helpers")
local image = require("fzf-lua-image.image")
local config = require("fzf-lua-image.config")

local function contains(fragment)
  for _, request in ipairs(H.requests) do
    if request:find(fragment, 1, true) then return true end
  end
  return false
end

return {
  { "renders a placeholder grid in the preview buffer without Snacks", function()
    local buf, win = H.window()
    local placement = image.attach(buf, { src = H.png(), win = win })
    H.wait(function() return contains("a=p") end)
    assert(contains("t=f"))
    assert(contains("U=1"))
    assert(#vim.api.nvim_buf_get_extmarks(buf, image.ns, 0, -1, {}) > 0)
    H.eq(nil, _G.Snacks)
    H.eq(nil, package.loaded["snacks"])
    placement:close()
    assert(contains("a=d"))
    H.eq(0, #vim.api.nvim_buf_get_extmarks(buf, image.ns, 0, -1, {}))
  end },
  { "updates image placement after resizing the window", function()
    local buf, win = H.window()
    local placement = image.attach(buf, { src = H.png(), win = win })
    H.wait(function() return contains("a=p") end)
    H.requests = {}
    vim.api.nvim_win_set_width(win, 6)
    placement:update()
    assert(contains("c=6"))
  end },
  { "cleans graphics when the preview window hides its buffer", function()
    local buf, win = H.window()
    local placement = image.attach(buf, { src = H.png(), win = win })
    H.wait(function() return contains("a=p") end)
    H.requests = {}
    local replacement = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, replacement)
    H.wait(function() return placement.closed end)
    assert(contains("a=d"))
    vim.api.nvim_buf_delete(replacement, { force = true })
  end },
  { "cancels rendering if the preview closes before conversion completes", function()
    local buf, win = H.window()
    local placement = image.attach(buf, { src = H.png(), win = win })
    placement:close()
    vim.wait(50, function() return false end, 10)
    H.eq(false, contains("a=p"))
  end },
  { "sends PNG bytes over SSH instead of the local filename", function()
    config.options.terminal.remote = true
    local buf, win = H.window()
    image.attach(buf, { src = H.png(), win = win })
    H.wait(function() return contains("a=p") end)
    assert(contains("t=d"))
    H.eq(false, contains("t=f"))
    assert(contains("iVBORw0KGgo"))
  end },
  { "splits SSH image transfers into protocol-sized chunks", function()
    config.options.terminal.remote = true
    local src = H.tmp .. "/noise.png"
    H.eq(0, vim.system({ H.magick(), "-size", "80x40", "plasma:fractal", src }):wait().code)
    local buf, win = H.window()
    image.attach(buf, { src = src, win = win })
    H.wait(function() return contains("a=p") end)
    local chunks = {}
    for _, request in ipairs(H.requests) do
      local data = request:match(";([A-Za-z0-9+/=]+)\27\\$")
      if data then
        assert(#data <= 4096)
        chunks[#chunks + 1] = data
      end
    end
    assert(#chunks > 1)
    local fd = assert(io.open(src, "rb"))
    H.eq(fd:read("*a"), vim.base64.decode(table.concat(chunks)))
    fd:close()
    assert(contains("m=1"))
    assert(contains("m=0"))
  end },
  { "uses cursor placements without placeholders and restores the cursor", function()
    config.options.terminal.placeholders = false
    local buf, win = H.window()
    image.attach(buf, { src = H.png(), win = win })
    H.wait(function() return contains("a=p") end)
    H.eq(false, contains("U=1"))
    assert(contains("\27[s"))
    assert(contains("\27[u"))
    H.eq(0, #vim.api.nvim_buf_get_extmarks(buf, image.ns, 0, -1, {}))
  end },
  { "displays conversion errors in the preview", function()
    local buf, win = H.window()
    image.attach(buf, { src = H.write(H.tmp .. "/broken.png", "broken"), win = win })
    H.wait(function() return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false)):find("PNG") end)
    H.eq(false, contains("a=p"))
  end },
}
