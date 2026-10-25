local H = require("tests.helpers")
local convert = require("fzf-lua-image.convert")

return {
  { "reads PNG dimensions and rejects broken headers", function()
    H.eq({ width = 160, height = 80 }, assert(convert.dim(H.png())))
    local size, err = convert.dim(H.write(H.tmp .. "/bad.png", "not a png"))
    H.eq(nil, size)
    assert(err:find("PNG"))
  end },
  { "opens PNG without invoking a converter", function()
    local src = H.png()
    H.patch(vim, "system", function() error("PNG must not start a converter") end)
    local result
    convert.get(src, function(file, size, err) result = { file = file, size = size, err = err } end)
    H.wait(function() return result ~= nil end)
    H.eq(src, result.file)
    H.eq({ width = 160, height = 80 }, result.size)
    H.eq(nil, result.err)
  end },
  { "reports missing files through the callback", function()
    local result
    convert.get(H.tmp .. "/missing.jpg", function(_, _, err) result = err end)
    H.wait(function() return result ~= nil end)
    assert(result:find("missing.jpg", 1, true))
  end },
  { "reports missing ImageMagick without launching a job", function()
    local src = H.write(H.tmp .. "/image.jpg", "jpeg")
    H.patch(vim.fn, "executable", function() return 0 end)
    local result
    convert.get(src, function(_, _, err) result = err end)
    H.wait(function() return result ~= nil end)
    assert(result:find("ImageMagick", 1, true))
  end },
  { "cancellation prevents a completed conversion from updating the preview", function()
    local called = false
    local cancel = convert.get(H.png(), function() called = true end)
    cancel()
    vim.wait(50, function() return false end, 10)
    H.eq(false, called)
  end },
  { "converts a file with spaces and caches the result", function()
    local src = H.tmp .. "/a picture ' quote.jpg"
    H.eq(0, vim.system({ H.magick(), H.png(), src }):wait().code)
    local result
    convert.get(src, function(file, size, err) result = { file = file, size = size, err = err } end)
    H.wait(function() return result ~= nil end)
    H.eq(nil, result.err)
    H.eq({ width = 160, height = 80 }, result.size)
    assert(result.file:find(H.tmp .. "/cache/", 1, true) == 1)
    H.patch(vim, "system", function() error("the converted file should be cached") end)
    local cached
    convert.get(src, function(file) cached = file end)
    H.wait(function() return cached ~= nil end)
    H.eq(result.file, cached)
  end },
  { "invalidates the conversion cache after the source changes", function()
    local src = H.tmp .. "/changing.jpg"
    H.eq(0, vim.system({ H.magick(), H.png(), src }):wait().code)
    local first, second
    convert.get(src, function(file) first = file end)
    H.wait(function() return first ~= nil end)
    H.eq(0, vim.system({ H.magick(), H.png(), "-resize", "80x40!", src }):wait().code)
    convert.get(src, function(file) second = file end)
    H.wait(function() return second ~= nil end)
    assert(first ~= second)
    H.eq({ width = 80, height = 40 }, convert.dim(second))
  end },
  { "returns converter failures without leaving partial PNGs", function()
    local result
    convert.get(H.write(H.tmp .. "/invalid.jpg", "invalid jpeg"), function(_, _, err) result = err end)
    H.wait(function() return result ~= nil end)
    assert(#result > 0)
    H.eq({}, vim.fn.glob(H.tmp .. "/cache/*.png", false, true))
  end },
  { "kills cancelled converters and removes their temporary output", function()
    local complete, output, killed
    H.patch(vim, "system", function(argv, _, cb)
      complete = cb
      output = argv[#argv]:gsub("^png:", "")
      return { kill = function(_, signal) killed = signal end }
    end)
    local called = false
    local cancel = convert.get(H.write(H.tmp .. "/cancel.jpg", "jpeg"), function() called = true end)
    cancel()
    H.eq(15, killed)
    local fd = assert(io.open(H.png(), "rb"))
    H.write(output, fd:read("*a"))
    fd:close()
    complete({ code = 0, stderr = "" })
    H.wait(function() return vim.fn.filereadable(output) == 0 end)
    H.eq(false, called)
  end },
}
