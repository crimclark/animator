local constants = require 'animator/lib/constants'
local helpers = {}

function helpers.findPosition(x, y)
  return constants.GRID_LENGTH * (y - 1) + x
end

function helpers.findXY(pos)
  return {x = (pos - 1) % constants.GRID_LENGTH + 1, y = math.ceil(pos/constants.GRID_LENGTH)}
end

return helpers
