local constants = include('animator/lib/constants')
local LENGTH = constants.GRID_LENGTH
local HEIGHT = constants.GRID_HEIGHT
local NAV_COL = constants.GRID_NAV_COL
local GRID_LEVELS = constants.GRID_LEVELS
local helpers = require 'animator/lib/helpers'
local SNAPSHOT_NUM = 4
local g = grid.connect()
local CLEAR_POSITION = 5
local TOGGLE_VIEW_POSITION = HEIGHT
local DIV_START = LENGTH - 7
local INTERSECT_START = 2
local SELECT_POSITION = 1

local GRID = {}
GRID.__index = GRID

function GRID.new(animator)
  local g = {
    snapshot = 0,
    held = nil,
    animator = animator,
    view = 1,
    selected = 1,
  }
  setmetatable(g, GRID)
  setmetatable(g, {__index = GRID})

  g.viewKeyHandlers = {g.mainKeyHandler, g.optionsKeyHandler}
  g.viewRedraws = {g.redrawMain, g.redrawOptions}
  return g
end


function GRID:redraw()
  self.viewRedraws[self.view](self)
end

function GRID:redrawMain()
  g:all(0)
  drawSteps(self.animator.stepLevels)
  redrawRightCol(self.snapshot)
  g:refresh()
end

function GRID:redrawOptions()
  g:all(0)
  self:drawOptions(self.selected)
  drawToggleViewPad()
  g:refresh()
end

function drawToggleViewPad()
  g:led(NAV_COL, TOGGLE_VIEW_POSITION, GRID_LEVELS.DIM)
end

function GRID:createKeyHandler()
  return function(x, y, z)
    self.viewKeyHandlers[self.view](self, x, y, z)
  end
end

function GRID:mainKeyHandler(x, y, z)
  if z == 1 then
    self:mainKeyDown(x, y)
  else
    self.held = nil
  end
end

function GRID:optionsKeyHandler(x, y, z)
  if z == 1 then
    self:optionsKeyDown(x, y)
  end
end

function GRID:mainKeyDown(x, y)
  if x <= LENGTH then
    self:handleSequence(x, y)
  elseif x == NAV_COL then
    self:handleRightColSelect(x, y)
  end
end

function GRID:optionsKeyDown(x, y)
  if x == NAV_COL and y == TOGGLE_VIEW_POSITION then
    self:toggleView()
  elseif x >= INTERSECT_START and x <= #constants.INTERSECT_OPS then
    local intersectID = 'seq' .. y .. 'intersect'
    params:set(intersectID, params:get(intersectID) == x and 1 or x)
    self:redraw()
  elseif x >= DIV_START then
    params:set('seq' .. y .. 'div', x - DIV_START + 1)
    self:redraw()
  elseif x == SELECT_POSITION then
    self.selected = y
    self.animator.redraw()
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
  elseif y == TOGGLE_VIEW_POSITION then
    self:toggleView()
  end
end

function GRID:toggleView()
  self.view = self.view % #self.viewRedraws + 1
  self.animator.redraw()
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

    self:createNewSequence(x, y)
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

function GRID:drawOptions(selected)
  local function drawOption(x, y, isOn)
    g:led(x, y, isOn and GRID_LEVELS.HIGH or GRID_LEVELS.LOW_MED)
  end

  g:led(SELECT_POSITION, selected, GRID_LEVELS.HIGH)
  local seqs = self.animator.sequencers

  for y=1,HEIGHT do
    for x=INTERSECT_START,#constants.INTERSECT_OPS do
      local intersect = seqs[y] and seqs[y].intersect or params:get('seq' .. y .. 'intersect')
      drawOption(x, y, intersect == x)
    end

    for x=DIV_START,LENGTH do
      local div = seqs[y] and seqs[y].div or params:get('seq' .. y .. 'div')
      drawOption(x, y, div == x - DIV_START + 1)
    end
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
    g:led(NAV_COL, i, snapshot == i and GRID_LEVELS.HIGH or GRID_LEVELS.LOW_MED)
  end

  g:led(NAV_COL, CLEAR_POSITION, GRID_LEVELS.DIM)
  drawToggleViewPad()
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
