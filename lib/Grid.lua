local pattern_time = require 'pattern_time'
local constants = include('animator/lib/constants')
local helpers = include('animator/lib/helpers')
local GRID_LENGTH = constants.GRID_LENGTH
local GRID_HEIGHT = constants.GRID_HEIGHT
local CANVAS_HEIGHT = constants.CANVAS_HEIGHT
local NAV_ROW = constants.GRID_NAV_ROW
local GRID_LEVELS = constants.GRID_LEVELS
local SNAPSHOT_NUM = 8
local PATTERN_NUM = 4
local g = grid.connect()
local CLEAR_POSITION = 15
local TOGGLE_VIEW_POSITION = constants.CANVAS_LENGTH
local DIV_START = GRID_LENGTH - 8
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
    patterns = {},
  }
  setmetatable(g, GRID)
  setmetatable(g, {__index = GRID})

  g.viewKeyHandlers = {g.mainKeyHandler, g.optionsKeyHandler}
  g.viewRedraws = {g.redrawMain, g.redrawOptions}

  for i=1,PATTERN_NUM do
    g.patterns[i] = pattern_time.new()
    g.patterns[i].process = function(e)
      g.animator.handleSelectSnapshot(e.x)
    end
  end

  return g
end


function GRID:redraw()
  self.viewRedraws[self.view](self)
end

function GRID:redrawMain()
  g:all(0)
  drawSteps(self.animator.stepLevels)
  self:redrawBottomRow()
  g:refresh()
end

function GRID:redrawOptions()
  g:all(0)
  self:drawOptions(self.selected)
  drawToggleViewPad()
  g:refresh()
end

function drawToggleViewPad()
  g:led(TOGGLE_VIEW_POSITION, NAV_ROW, GRID_LEVELS.DIM)
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
  if y <= CANVAS_HEIGHT then
    self:handleSequence(x, y)
  elseif y == NAV_ROW then
    self:handleBottomRowSelect(x, y)
  end
end

function GRID:optionsKeyDown(x, y)
  if y == NAV_ROW and x == TOGGLE_VIEW_POSITION then
    return self:toggleView()
  end

  if x >= INTERSECT_START and x <= #constants.INTERSECT_OPS then
    local intersectID = 'seq' .. y .. 'intersect'
    params:set(intersectID, params:get(intersectID) == x and 1 or x)
  elseif x >= DIV_START then
    params:set('seq' .. y .. 'div', x - DIV_START + 1)
  end

  self.selected = y
  self.animator.redraw()
end

function GRID:handleBottomRowSelect(x, y)
  local animator = self.animator
  local isClearHeld = self.held and self.held.y == NAV_ROW and self.held.x == CLEAR_POSITION

  if x >= 1 and x <= SNAPSHOT_NUM then
    animator.handleSelectSnapshot(x, isClearHeld)
    self.snapshot = x

    for i=1,PATTERN_NUM do
      self.patterns[i]:watch{x=x}
    end

    animator.redraw()
  elseif x >= 10 and x <= 13 then
    self:handleSelectPattern(x-9, isClearHeld)
  elseif x == CLEAR_POSITION then
    self:setHeld(x, y)
  elseif x == TOGGLE_VIEW_POSITION then
    self:toggleView()
  end
end

function GRID:handleSelectPattern(i, isClearHeld)
  local function stopOtherPattern(current, patterns)
    for i=1,PATTERN_NUM do
      local otherPat = patterns[i]
      if i ~= current and (otherPat.rec == 1 or otherPat.play == 1) then
        otherPat:rec_stop()
        otherPat:stop()
      end
    end
  end

  local pattern = self.patterns[i]
  if pattern.rec == 1 then
    pattern:rec_stop()
    pattern:stop()
    if isClearHeld then pattern:clear() else pattern:start() end
  elseif pattern.count == 0 then
    stopOtherPattern(i, self.patterns)
    pattern:rec_start()
  elseif pattern.play == 1 then
    if isClearHeld then
      pattern:clear()
      pattern:rec_start()
    else
      pattern:stop()
    end
  else
    stopOtherPattern(i, self.patterns)
    if isClearHeld then
      pattern:clear()
      pattern:rec_start()
    else
      pattern:start()
    end
  end

  self.animator.redraw()
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

  for y=1,GRID_HEIGHT do
    for x=INTERSECT_START,#constants.INTERSECT_OPS do
      local intersect = seqs[y] and seqs[y].intersect or params:get('seq' .. y .. 'intersect')
      drawOption(x, y, intersect == x)
    end

    for x=DIV_START,GRID_LENGTH-1 do
      local div = seqs[y] and seqs[y].div or params:get('seq' .. y .. 'div')
      drawOption(x, y, div == x - DIV_START + 1)
    end
  end
end

function GRID:redrawBottomRow()
  drawSnapshots(self)
  drawPatterns(self.patterns);
  g:led(CLEAR_POSITION, NAV_ROW, GRID_LEVELS.DIM)
  drawToggleViewPad()
end

function drawSnapshots(self)
  for i=1,SNAPSHOT_NUM do
    if self.snapshot == i then
      g:led(i, NAV_ROW, GRID_LEVELS.HIGH)
    elseif self.animator.snapshots[i] ~= nil then
      g:led(i, NAV_ROW, GRID_LEVELS.LOW_MED)
    else
      g:led(i, NAV_ROW, GRID_LEVELS.DIM)
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

function drawPatterns(patterns)
  for i=1,PATTERN_NUM do
    local x = i+9
    if patterns[i].rec == 1 then g:led(x, NAV_ROW, GRID_LEVELS.HIGH)
    elseif patterns[i].play == 1 then g:led(x, NAV_ROW, GRID_LEVELS.MED)
    elseif patterns[i].count > 0 then g:led(x, NAV_ROW, GRID_LEVELS.LOW_MED)
    else g:led(x, NAV_ROW, GRID_LEVELS.DIM) end
  end
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
