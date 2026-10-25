local H = require("tests.helpers")
local util = require("fzf-lua-image.util")

return {
  { "fits wide images while preserving aspect ratio", function()
    H.eq({ width = 10, height = 3 }, util.fit({ width = 160, height = 80 }, { width = 10, height = 5 }, { cell_width = 8, cell_height = 16 }))
  end },
  { "fits tall images and never returns a zero cell", function()
    H.eq({ width = 1, height = 4 }, util.fit({ width = 1, height = 10000 }, { width = 12, height = 4 }, { cell_width = 8, cell_height = 16 }))
  end },
  { "does not enlarge small images", function()
    H.eq({ width = 1, height = 1 }, util.fit({ width = 1, height = 1 }, { width = 12, height = 4 }, { cell_width = 8, cell_height = 16 }))
  end },
}
