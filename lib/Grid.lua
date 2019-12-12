local constants = require 'animator/lib/constants'
local LENGTH = constants.GRID_LENGTH
local NAV_COL = constants.GRID_NAV_COL
local helpers = require 'animator/lib/helpers'
local SNAPSHOT_NUM = 4
local g = grid.connect()
local GRID_LEVELS = {DIM = 2, LOW_MED = 4, MED = 8, HIGH = 14 }

local GRID = {}
GRID.__index = GRID

function GRID.new(animator)
  local g = {
    snapshot = 0,
    held = nil,
    animator = animator,
  }
  setmetatable(g, GRID)
  setmetatable(g, {__index = GRID})
  return g
end

function GRID:redraw(levels)
  g:all(0)
  drawSteps(levels)
  redrawRightCol(self.snapshot)
  g:refresh()
end

function GRID:createKeyHandler()
  return function(x, y, z) self:_key(x, y, z) end
end

function GRID:_key(x, y, z)
  if z == 1 then
    self:keyDown(x, y, z)
  else
    self.held = nil
  end
end

function GRID:keyDown(x, y)
  if x <= LENGTH then
    self:handleSequence(x, y)
  elseif x == NAV_COL then
    self.animator.handleNavSelect(y)
  end
end

function GRID:handleSequence(x, y)
  local held = self.held
  local findPos = helpers.findPosition
  local posHeld
  if held ~= nil then posHeld = findPos(held.x, held.y) end
  local pos = findPos(x, y)
  local enabled = self.animator.enabled

  if posHeld ~= nil then
    if enabled[posHeld] > 0 and enabled[pos] > 0 then
      local overlapIndex = self:findOverlapIndex(pos, posHeld)
      if overlapIndex then
        return self:handleOverlap(pos, posHeld, overlapIndex)
      end
    end

    self.animator.createNewSequence(x, y)
  else
    self.animator.toggleStepOn(x, y)
    self.held = {x = x, y = y}
  end
  self.animator.redraw()
end

function GRID:findOverlapIndex(posA, posB)
  for i=1,#self.animator.sequencers do
    local stepMap = self.animator.sequencers[i].stepMap
    if stepMap[posA] and stepMap[posB] then return i end
  end
end

function GRID:handleOverlap(pos, posHeld, index)
  local seq = self.animator.sequencers[index]
  local steps = seq.steps
  local first = helpers.findPosition(steps[1].x, steps[1].y)
  local last = helpers.findPosition(steps[seq.length].x, steps[seq.length].y)

  if (pos == first and posHeld == last) or (posHeld == first and pos == last) then
    self.animator.clearSeq(index)
    self.animator.redraw()
  end
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
