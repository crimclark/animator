local constants = require 'animator/lib/constants'
local helpers = require 'animator/lib/helpers'
local NAV_COL = constants.GRID_NAV_COL
local SNAPSHOT_NUM = 4
local g = grid.connect()
local GRID_LEVELS = {DIM = 2, LOW_MED = 4, MED = 8, HIGH = 14 }

local GRID = {}
GRID.__index = GRID

function GRID.new()
  local g = {
    snapshot = 1
  }

  setmetatable(g, self)
  return g
end

function GRID:redraw(levels)
  g:all(0)
  drawSteps(levels)
  redrawRightCol(self.snapshot)
  g:refresh()
end

function drawSteps(levels)
  local findXY = helpers.findXY
  for pos,level in pairs(levels) do
    local step = findXY(pos)
    g:led(step.x, step.y, level)
  end
end

function redrawRightCol(snapshot)
  for i=1,SNAPSHOT_NUM do
    if snapshot == i then
      g:led(NAV_COL, i, GRID_LEVELS.HIGH)
    else
      g:led(NAV_COL, i, GRID_LEVELS.LOW_MED)
    end
  end
end

return GRID
