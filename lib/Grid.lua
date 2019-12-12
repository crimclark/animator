local constants = require 'animator/lib/constants'
local LENGTH = constants.GRID_LENGTH
local NAV_COL = constants.GRID_NAV_COL
local GRID_LEVELS = constants.GRID_LEVELS
local helpers = require 'animator/lib/helpers'
local SNAPSHOT_NUM = 4
local g = grid.connect()
local CLEAR_POSITION = 6

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
    self:keyDown(x, y)
  else
    self.held = nil
  end
end

function GRID:keyDown(x, y)
  if x <= LENGTH then
    self:handleSequence(x, y)
  elseif x == NAV_COL then
    self:handleRightColSelect(x, y)
  end
end

function GRID:handleRightColSelect(x, y)
  local animator = self.animator
  if y >= 1 and y <= SNAPSHOT_NUM then
    local isClearHeld = self.held and self.held.x == NAV_COL and self.held.y == CLEAR_POSITION
    if isClearHeld then
      if self.snapshot == y then self.snapshot = 0 end
      animator.snapshots[y] = nil
    else
      self.snapshot = y
      animator.createNewSnapshot(y)
    end

    animator.redraw()
  elseif y == CLEAR_POSITION then
    self:setHeld(x, y)
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

    GRID:createNewSequence(x, y)
  else
    self:toggleStepOn(x, y)
    self:setHeld(x, y)
  end
  self.animator.redraw()
end

function GRID:createNewSequence(x, y)
  local animator = self.animator
  local steps = getNewLineSteps(self.held, {x = x, y = y})
  if steps ~= nil then animator.addNewSequence(steps) end
end

function GRID:toggleStepOn(x, y)
  local animator = self.animator
  local pos = helpers.findPosition(x, y)
  if animator.on[pos] > 0 then
    animator.on[pos] = 0
  elseif animator.enabled[pos] > 0 then
    animator.on[pos] = animator.enabled[pos]
  end
end

function GRID:setHeld(x, y)
  self.held = {x = x, y = y}
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

  g:led(NAV_COL, SNAPSHOT_NUM+2, GRID_LEVELS.LOW_MED)
  g:led(NAV_COL, SNAPSHOT_NUM+4, GRID_LEVELS.LOW_MED)
end

function getNewLineSteps(a, b)
  if a.x == b.x and a.y == b.y then return end
  if a.y == b.y then
    return getStepsHorizontal(a, b)
  elseif a.x == b.x then
    return getStepsVertical(a, b)
  elseif math.abs(a.x - b.x) == math.abs(a.y - b.y) then
    return getStepsDiagonal(a, b)
  end
end

function getStepsHorizontal(a, b)
  local steps = {}
  if a.x < b.x then
    for i = a.x, b.x do
      steps[#steps+1] = {x = i, y = a.y}
    end
    return steps
  else
    for i = a.x, b.x, -1 do
      steps[#steps+1] = {x = i, y = a.y}
    end
    return steps
  end
end

function getStepsVertical(a, b)
  local steps = {}
  if a.y < b.y then
    for i = a.y, b.y do
      steps[#steps+1] = {x = a.x, y = i}
    end
  else
    for i = a.y, b.y, -1 do
      steps[#steps+1] = {x = a.x, y = i}
    end
  end
  return steps
end

function getStepsDiagonal(a, b)
  local steps = {}
  local y = a.y

  local function addStep(x)
    steps[#steps+1] = {x = x, y = y}
    if a.y > b.y then
      y = y - 1
    else
      y = y + 1
    end
  end

  if a.x < b.x then
    for i = a.x,b.x do addStep(i) end
  else
    for i = a.x,b.x,-1 do addStep(i) end
  end

  return steps
end

return GRID
