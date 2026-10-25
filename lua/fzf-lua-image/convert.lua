-- SPDX-License-Identifier: Apache-2.0
-- PNG header parsing and conversion arguments adapted from snacks.nvim's
-- image/{util,convert}.lua. Modified for cancellable, local-file-only previews.
-- See NOTICE and LICENSES/snacks.nvim.txt.
local M = {}
local config = require("fzf-lua-image.config")
local uv = vim.uv or vim.loop

---Read dimensions directly from the PNG IHDR chunk, without ImageMagick.
function M.dim(file)
  local fd = io.open(file, "rb")
  if not fd then return nil, "Unable to read PNG: " .. file end
  local header = fd:read(24)
  fd:close()
  if not header or #header < 24 or header:sub(1, 8) ~= "\137PNG\r\n\26\n" or header:sub(13, 16) ~= "IHDR" then
    return nil, "Invalid PNG header: " .. file
  end
  local function uint32(offset)
    local a, b, c, d = header:byte(offset, offset + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
  end
  local width, height = uint32(17), uint32(21)
  if width == 0 or height == 0 then return nil, "Invalid PNG dimensions: " .. file end
  return { width = width, height = height }
end

---Resolve a local image to PNG. The returned function cancels pending work.
---@param src string
---@param cb fun(file: string?, size: table?, err: string?)
---@return function cancel
function M.get(src, cb)
  local cancelled, process, temporary = false, nil, nil
  local function finish(file, size, err)
    vim.schedule(function()
      if not cancelled then cb(file, size, err) end
    end)
  end
  local function cancel()
    cancelled = true
    if process then process:kill(15) end
  end
  src = vim.fn.fnamemodify(src, ":p")
  local stat = uv.fs_stat(src)
  if not stat or stat.type ~= "file" then
    finish(nil, nil, "Unable to read image: " .. src)
    return cancel
  end
  local ext = vim.fn.fnamemodify(src, ":e"):lower()
  if ext == "png" then
    local size, err = M.dim(src)
    finish(size and src or nil, size, err)
    return cancel
  end
  local formats = config.options.convert.magick
  local args = formats[ext] or ((ext == "svg") and formats.vector) or formats.default
  -- NUL-delimited Lua strings become Blobs at the Vimscript boundary in 0.10.
  local key = vim.fn.sha256(vim.json.encode({ src, stat.size, stat.mtime.sec, stat.mtime.nsec, args }))
  local target = config.options.cache .. "/" .. key .. ".png"
  local size = M.dim(target)
  if size then
    finish(target, size)
    return cancel
  end
  local executable = vim.fn.executable("magick") == 1 and "magick"
    or (vim.fn.has("win32") == 0 and vim.fn.executable("convert") == 1 and "convert")
  if not executable then
    finish(nil, nil, "ImageMagick is required for " .. ext .. " previews (install `magick`).")
    return cancel
  end
  vim.fn.mkdir(config.options.cache, "p")
  temporary = config.options.cache .. "/" .. key .. "-" .. vim.fn.getpid() .. "-" .. uv.hrtime() .. ".png"
  local argv = { executable }
  for _, arg in ipairs(args) do
    -- A function replacement preserves '%' characters in filenames.
    argv[#argv + 1] = tostring(arg):gsub("{src}", function() return src end)
  end
  argv[#argv + 1] = "png:" .. temporary
  process = vim.system(argv, { text = true }, function(result)
    vim.schedule(function()
      process = nil
      local converted, err = M.dim(temporary)
      if cancelled then
        uv.fs_unlink(temporary)
        return
      end
      if result.code ~= 0 or not converted then
        uv.fs_unlink(temporary)
        finish(nil, nil, vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or err or "Image conversion failed")
        return
      end
      local ok, rename_err = uv.fs_rename(temporary, target)
      if not ok then
        uv.fs_unlink(temporary)
        finish(nil, nil, rename_err)
      else
        finish(target, converted)
      end
    end)
  end)
  return cancel
end

return M
