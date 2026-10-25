-- SPDX-License-Identifier: Apache-2.0
-- Adapted from snacks.nvim's image/{image,placement}.lua. Modified for a single
-- fzf-lua preview window, with cancellable conversion and explicit cleanup.
-- See NOTICE and LICENSES/snacks.nvim.txt.
local M = {}
local terminal = require("fzf-lua-image.terminal")
local convert = require("fzf-lua-image.convert")
local util = require("fzf-lua-image.util")
local diacritics = require("fzf-lua-image.diacritics")
local api = vim.api
local placements = {}
local sequence = 30
local placeholder = vim.fn.nr2char(0x10EEEE)
M.ns = api.nvim_create_namespace("fzf-lua-image")

local Placement = {}
Placement.__index = Placement

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  vim.bo[buf].modifiable = false
end

function Placement:valid()
  return not self.closed and api.nvim_buf_is_valid(self.buf) and api.nvim_win_is_valid(self.win)
    and api.nvim_win_get_buf(self.win) == self.buf
end

function Placement:error(err)
  if not self:valid() then return end
  set_lines(self.buf, vim.split("Image preview failed\n" .. tostring(err), "\n", { plain = true }))
end

function Placement:close()
  if self.closed then return end
  self.closed = true
  if self.cancel then self.cancel() end
  if self.sent then
    -- Uppercase I also frees the image data. Never delete other plugins' images.
    terminal.request({ a = "d", d = "I", i = self.id })
  end
  if api.nvim_buf_is_valid(self.buf) then
    api.nvim_buf_clear_namespace(self.buf, M.ns, 0, -1)
    vim.b[self.buf].fzf_lua_image = nil
  end
  placements[self.buf] = nil
  api.nvim_set_hl(0, self.hl, {})
  pcall(api.nvim_del_augroup_by_id, self.group)
end

function Placement:send()
  terminal.setup()
  if terminal.env().remote then
    local fd, err = io.open(self.file, "rb")
    if not fd then return nil, err end
    local data = vim.base64.encode(fd:read("*a"))
    fd:close()
    local offset = 1
    while offset <= #data do
      local chunk = data:sub(offset, offset + 4095)
      local first = offset == 1
      offset = offset + #chunk
      local request = first and { a = "t", t = "d", i = self.id, f = 100 } or {}
      request.m = offset > #data and 0 or 1
      request.data = chunk
      terminal.request(request)
    end
  else
    terminal.request({ a = "t", t = "f", i = self.id, f = 100, data = vim.base64.encode(self.file) })
  end
  self.sent = true
  return true
end

function Placement:render_grid(size)
  api.nvim_set_hl(0, self.hl, { fg = self.id, sp = 1, bg = "NONE", nocombine = true })
  for row = 1, size.height do
    local line = {}
    for col = 1, size.width do
      line[#line + 1] = placeholder .. vim.fn.nr2char(diacritics[row]) .. vim.fn.nr2char(diacritics[col])
    end
    api.nvim_buf_set_extmark(self.buf, M.ns, row - 1, 0, {
      virt_text = { { table.concat(line), self.hl } },
      virt_text_pos = "overlay",
      virt_text_win_col = 0,
      virt_text_hide = false,
    })
  end
end

function Placement:update()
  if not self:valid() then
    self:close()
    return
  end
  if not self.size then return end
  local env = terminal.env()
  local size = util.fit(self.size, {
    width = api.nvim_win_get_width(self.win),
    height = api.nvim_win_get_height(self.win),
  }, terminal.size())
  if env.placeholders then
    size.width, size.height = math.min(#diacritics, size.width), math.min(#diacritics, size.height)
  end
  local state = { size = size, pos = api.nvim_win_get_position(self.win) }
  if vim.deep_equal(self.state, state) then return end
  self.state = state
  if not self.sent then
    local ok, err = self:send()
    if not ok then return self:error(err) end
  else
    terminal.request({ a = "d", d = "i", i = self.id, p = 1 })
  end
  local lines = {}
  for _ = 1, size.height do lines[#lines + 1] = "" end
  set_lines(self.buf, lines)
  api.nvim_buf_clear_namespace(self.buf, M.ns, 0, -1)
  vim.wo[self.win].winblend = 0
  if env.placeholders then
    terminal.request({ a = "p", U = 1, i = self.id, p = 1, C = 1, c = size.width, r = size.height })
    self:render_grid(size)
  else
    -- screenpos includes float borders, tablines and window bars.
    api.nvim_win_call(self.win, function() vim.fn.winrestview({ topline = 1, lnum = 1, col = 0, leftcol = 0 }) end)
    vim.cmd("redraw")
    local pos = vim.fn.screenpos(self.win, 1, 1)
    terminal.write("\27[s\27[" .. pos.row .. ";" .. pos.col .. "H")
    terminal.request({ a = "p", i = self.id, p = 1, C = 1, c = size.width, r = size.height })
    terminal.write("\27[u")
  end
end

---@param buf integer
---@param opts {src: string, win: integer}
---@return table placement
function M.attach(buf, opts)
  M.clear(buf)
  sequence = sequence + 1
  -- The placeholder foreground carries a 24-bit image ID. Reserve ten bits for
  -- the Neovim process, as Snacks does, to separate terminal-sharing instances.
  local id = (vim.fn.getpid() % 1024) * 16384 + sequence % 16384
  local self = setmetatable({
    id = id, buf = buf, win = opts.win, hl = "FzfLuaImage" .. id,
    group = api.nvim_create_augroup("fzf-lua-image." .. id, { clear = true }),
  }, Placement)
  placements[buf] = self
  vim.b[buf].fzf_lua_image = true
  vim.bo[buf].filetype = "image"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modeline = false
  set_lines(buf, { "Loading image…" })
  vim.wo[self.win].winblend = 0
  api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "BufWinLeave" }, {
    group = self.group, buffer = buf, callback = function() self:close() end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = self.group, pattern = tostring(self.win), callback = function() self:close() end,
  })
  api.nvim_create_autocmd({ "WinResized", "VimResized", "WinScrolled" }, {
    group = self.group, callback = function() vim.schedule(function() self:update() end) end,
  })
  api.nvim_create_autocmd("VimLeavePre", {
    group = self.group, callback = function() self:close() end,
  })
  self.cancel = convert.get(opts.src, function(file, size, err)
    if not self:valid() then return self:close() end
    if err then return self:error(err) end
    self.file, self.size = file, size
    self:update()
  end)
  return self
end

function M.clear(buf)
  if buf then
    if placements[buf] then placements[buf]:close() end
  else
    for _, placement in pairs(vim.tbl_extend("force", {}, placements)) do placement:close() end
  end
end

return M
