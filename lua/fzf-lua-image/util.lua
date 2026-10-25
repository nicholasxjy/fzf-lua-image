-- SPDX-License-Identifier: Apache-2.0
-- Adapted from snacks.nvim's image/util.lua. Modified for standalone previews.
-- See NOTICE and LICENSES/snacks.nvim.txt.
local M = {}

---Fit pixel dimensions into terminal cells without enlarging the image.
---@param pixels {width: number, height: number}
---@param area {width: number, height: number}
---@param cell {cell_width: number, cell_height: number}
function M.fit(pixels, area, cell)
  local width = math.max(1, math.ceil(pixels.width / cell.cell_width))
  local height = math.max(1, math.ceil(pixels.height / cell.cell_height))
  local scale = math.min(1, area.width / width, area.height / height)
  return {
    width = math.max(1, math.min(area.width, math.floor(width * scale + 0.5))),
    height = math.max(1, math.min(area.height, math.floor(height * scale + 0.5))),
  }
end

return M
