local constants = require 'lib/constants'
local helpers = require 'lib/helpers'
local parameters = include('lib/parameters')
local Sequencer = include('lib/Sequencer')
local MusicUtil = require 'musicutil'
local findPosition = helpers.findPosition
local HEIGHT,LENGTH,NAV_COL = constants.GRID_HEIGHT, constants.GRID_LENGTH, constants.GRID_NAV_COL
local STEP_NUM = HEIGHT*LENGTH
local MUTE, OCTAVE, RESET, RESET_GLOBAL = 'mute', 'octave', 'reset', 'reset_global'
local g = grid.connect()
local GRID_LEVELS = {DIM = 2, LOW_MED = 4, MED = 8, HIGH = 14}
local state = {
  held = nil,
  selectedSnapshot = 0,
}
local sequencers = {}
local clk = metro.init()
engine.name = "MollyThePoly"

local animator = {}
animator.clock = clk

local snapshots = {}

function copyTable(tbl)
  local copy = {}
  for k,v in pairs(tbl) do copy[k] = v end
  return copy
end

function initStepState()
  local steps = {}
  for i=1,STEP_NUM do steps[i] = 0 end
  return steps
end

local on = initStepState()
local enabled = initStepState()

local Snapshot = {}

function Snapshot.new(options)
  local snapshot = {
    sequencers = {},
    on = copyTable(options.on),
    enabled = copyTable(options.enabled),
  }
  for i=1,#options.sequencers do
    local steps = copyTable(options.sequencers[i].steps)
    table.insert(snapshot.sequencers, Sequencer.new{steps = steps})
  end

  return snapshot
end

function init()
  math.randomseed(os.time())
  parameters.init(animator)
  clk.event = count
  g.key = gridKey
  clk:start()
  redraw()
end

function count()
  local play = {}
  local findPos = findPosition
  local noteOn = engine.noteOn

  for i=1,#sequencers do
    local seq = sequencers[i]
    seq.index = seq.index % seq.length + 1
    local currentStep = seq.steps[seq.index]
    local pos = findPos(currentStep.x, currentStep.y)
    if on[pos] > 0 then
      if play[pos] == nil then
        play[pos] = {seq.ID}
      else
        play[pos][#play[pos]+1] = seq.ID
      end
    end
  end

  for pos,seqs in pairs(play) do
    local note = notes[pos]
    if #seqs > 1 then note = note + 12 end
    noteOn(note, MusicUtil.note_num_to_freq(note), 1)
  end
  gridDraw()
  redraw()
end

function redraw()
  screen.clear()
  screen.aa(1)
  screenDrawSteps()
  screen.fill()
  screen.update()
end

function key(n, z) end

function moveSteps(steps, axis, delta, wrap)
  clearStepState(steps)
  local newOn = {}

  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    step[axis] = (step[axis] + delta - 1) % wrap + 1
    if on[pos] > 0 then
      newOn[pos] = -1
      newOn[findPosition(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function moveSequencers(axis, delta, wrap)
  local newOn = {}
  for i=1,#sequencers do
    local resp = moveSteps(sequencers[i].steps, axis, delta, wrap)
    for pos,n in pairs(resp) do
      if newOn[pos] == nil then newOn[pos] = n
      else newOn[pos] = newOn[pos] + n
      end
    end
  end
  for pos,n in pairs(newOn) do on[pos] = on[pos] + n end
end

function enc(n, delta)
  if n == 2 then
    moveSequencers('y', delta, HEIGHT)
    gridDraw()
    redraw()
  elseif n == 3 then
    moveSequencers('x', delta, LENGTH)
    gridDraw()
    redraw()
  end
end

function gridKey(x, y, z)
  if z == 1 then
    handleGridKeyDown(x, y)
  else
    state.held = nil
  end
end

function handleGridKeyDown(x, y)
  if x <= LENGTH then
    mainSeqGridHandler(x, y)
  elseif x == NAV_COL then
    handleNavSelect(y)
  end
end

function handleNavSelect(y)
  if y >= 1 and y <= 4 then
    state.selectedSnapshot = y

    if snapshots[y] == nil then
      table.insert(snapshots, Snapshot.new{on = on, enabled = enabled, sequencers = sequencers})
    end

    on = copyTable(snapshots[y].on)
    enabled = copyTable(snapshots[y].enabled)
    sequencers = copyTable(snapshots[y].sequencers)
    gridDraw()
    redraw()
  end
end

function mainSeqGridHandler(x, y)
  if state.held ~= nil then
    for i=1,#sequencers do
      local ln = sequencers[i].length
      local steps = sequencers[i].steps
      if (state.held.x == steps[1].x and state.held.y == steps[1].y and x == steps[ln].x and y == steps[ln].y)
              or (state.held.x == steps[ln].x and state.held.y == steps[ln].y and x == steps[1].x and y == steps[1].y) then
        clearSeq(i)
        gridDraw()
        redraw()
        screen.clear()
        return
      end
    end

    local steps = getNewLineSteps(state.held, {x = x, y = y})
    if steps ~= nil then
      sequencers[#sequencers+1] = Sequencer.new{steps = steps}
      updateEnabled(steps)
      updateOnState(steps)
      state.held = {x = x, y = y}
    end
  else
    local pos = findPosition(x, y)
    if on[pos] > 0 then
      on[pos] = 0
    elseif enabled[pos] > 0 then
      -- set on to same number of enabled at position
      on[pos] = enabled[pos]
    end
    state.held = {x = x, y = y}
  end
  gridDraw()
  redraw()
  screen.clear()
end

function clearSeq(index)
  clearStepState(sequencers[index].steps)
  clearOnState(sequencers[index].steps)
  table.remove(sequencers, index)
end

function getStepLevels()
  local levels = {}
  local findPos = findPosition
  local max = math.max
  for i=1,#sequencers do
    local seq = sequencers[i]
    local steps = seq.steps
    for i=1,#steps do
      local step = steps[i]
      local pos = findPos(step.x, step.y)
      -- step activated
      if on[pos] > 0 then
        if i == seq.index then
          levels[pos] = GRID_LEVELS.HIGH
        else
          levels[pos] = levels[pos] == nil
                  and GRID_LEVELS.MED
                  or max(levels[pos], GRID_LEVELS.MED)
        end
        -- step highlighted but not activated
      elseif i == seq.index then
        levels[pos] = levels[pos] == nil
                and GRID_LEVELS.LOW_MED
                or max(levels[pos], GRID_LEVELS.LOW_MED)
        -- step not highlighted or activated
      else
        levels[pos] = levels[pos] == nil
                and GRID_LEVELS.DIM
                or max(levels[pos], GRID_LEVELS.DIM)
      end
    end
  end
  return levels
end

function screenDrawSteps()
  local findXY = helpers.findXY
  for pos,level in pairs(getStepLevels()) do
    local step = findXY(pos)
    local padding = 4
    screen.level(level)
    screen.rect(step.x+(padding*step.x) - padding, step.y+(padding*step.y) - padding, 3, 3)
    screen.fill()
    screen.stroke()
    screen.update()
  end
end

function gridDraw()
  g:all(0)
  local findXY = helpers.findXY
  for pos,level in pairs(getStepLevels()) do
    local step = findXY(pos)
    g:led(step.x, step.y, level)
  end

  for i=1,4 do
    if state.selectedSnapshot == i then
      g:led(NAV_COL, i, GRID_LEVELS.HIGH)
    else
      g:led(NAV_COL, i, GRID_LEVELS.LOW_MED)
    end
  end
  g:refresh()
end

function updateEnabled(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    enabled[pos] = enabled[pos] + 1
  end
end

function updateOnState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    if on[pos] > 0 then
      on[pos] = on[pos] + 1
    end
  end
end

function clearStepState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    enabled[pos] = enabled[pos] - 1
  end
end

function clearOnState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    if on[pos] > 0 then
      on[pos] = on[pos] - 1
    end
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
