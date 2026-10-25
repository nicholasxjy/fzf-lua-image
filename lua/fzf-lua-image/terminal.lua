-- SPDX-License-Identifier: Apache-2.0
-- Adapted from snacks.nvim's image/terminal.lua. Modified to remove Snacks
-- dependencies and allow environment detection and explicit configuration.
-- See NOTICE and LICENSES/snacks.nvim.txt.
local M = {}
local config = require("fzf-lua-image.config")
local detected_terminal
local did_detect = false
local did_setup_tmux = false

function M.env()
  local opts = config.options.terminal
  local term = ((vim.env.TERM_PROGRAM or "") .. " " .. (vim.env.TERM or "") .. " " .. (detected_terminal or "")):lower()
  local kitty = term:find("kitty", 1, true) ~= nil or vim.env.KITTY_WINDOW_ID ~= nil
  local ghostty = term:find("ghostty", 1, true) ~= nil or vim.env.GHOSTTY_RESOURCES_DIR ~= nil
  local wezterm = term:find("wezterm", 1, true) ~= nil
  local supported = kitty or ghostty or wezterm
  if vim.env.ZELLIJ or term:find("zellij", 1, true) then supported = false end
  if opts.supported ~= nil then supported = opts.supported end
  local placeholders = kitty or ghostty
  if opts.placeholders ~= nil then placeholders = opts.placeholders end
  local remote = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_CLIENT ~= nil
  if opts.remote ~= nil then remote = opts.remote end
  return { supported = supported, placeholders = placeholders, remote = remote, tmux = vim.env.TMUX ~= nil }
end

function M.write(data)
  if vim.env.TMUX then
    data = "\27Ptmux;" .. data:gsub("\27", "\27\27") .. "\27\\"
  end
  if vim.api.nvim_ui_send then
    vim.api.nvim_ui_send(data)
  else
    io.stdout:write(data)
    io.stdout:flush()
  end
end

---@param opts table<string, string|number|boolean>
function M.request(opts)
  local fields = {}
  for key, value in pairs(opts) do
    if key ~= "data" and key ~= "q" then fields[#fields + 1] = key .. "=" .. tostring(value) end
  end
  if opts.q ~= false then fields[#fields + 1] = "q=" .. tostring(opts.q or 2) end
  table.sort(fields)
  M.write("\27_G" .. table.concat(fields, ",") .. (opts.data and ";" .. opts.data or "") .. "\27\\")
end

function M.setup()
  if vim.env.TMUX and not did_setup_tmux then
    did_setup_tmux = true
    pcall(vim.fn.system, { "tmux", "set-option", "-p", "allow-passthrough", "on" })
  end
end

---Probe the terminal name only when environment detection was inconclusive.
function M.supported()
  if config.options.force or M.env().supported then return true end
  if config.options.terminal.supported ~= nil or did_detect or #vim.api.nvim_list_uis() == 0 then return false end
  did_detect = true
  M.setup()
  if vim.env.TMUX then
    local ok, name = pcall(vim.fn.system, { "tmux", "display-message", "-p", "#{client_termname}" })
    if ok then detected_terminal = name end
    if M.env().supported then return true end
  end
  local done = false
  local id = vim.api.nvim_create_autocmd("TermResponse", {
    callback = function(ev)
      local sequence = ev.data and ev.data.sequence or vim.v.termresponse
      local name = sequence:match("P>|(%S+)")
      if name then
        detected_terminal = name
        done = true
        return true
      end
    end,
  })
  M.write("\27[>q")
  vim.wait(1000, function() return done end, 10)
  pcall(vim.api.nvim_del_autocmd, id)
  return M.env().supported
end

local ffi_ready = false
function M.size()
  local opts = config.options.terminal
  local width, height = 8, 16
  if not (opts.cell_width and opts.cell_height) then
    local ffi = require("ffi")
    if not ffi_ready then
      ffi.cdef([[
        typedef struct { unsigned short row, col, xpixel, ypixel; } fzf_lua_image_winsize;
        int ioctl(int, int, ...);
      ]])
      ffi_ready = true
    end
    pcall(function()
      local request = vim.fn.has("linux") == 1 and 0x5413 or 0x40087468
      local size = ffi.new("fzf_lua_image_winsize")
      if ffi.C.ioctl(1, request, size) == 0 and size.col > 0 and size.row > 0 and size.xpixel > 0 and size.ypixel > 0 then
        width, height = size.xpixel / size.col, size.ypixel / size.row
      end
    end)
  end
  return { cell_width = opts.cell_width or width, cell_height = opts.cell_height or height }
end

return M
