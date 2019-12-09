local constants = include('lib/constants')
local helpers = include('lib/helpers')
local parameters = include('lib/parameters')
local Sequencer = include('lib/Sequencer')
local lfo = include("lib/hnds")
local MusicUtil = require 'musicutil'
local findPosition = helpers.findPosition
local HEIGHT,LENGTH,NAV_COL = constants.GRID_HEIGHT, constants.GRID_LENGTH, constants.GRID_NAV_COL
local STEP_NUM = HEIGHT*LENGTH
local MUTE, OCTAVE, RESET, RESET_GLOBAL = 'mute', 'octave', 'reset', 'reset_global'
local g = grid.connect()
local GRID_LEVELS = {DIM = 3, LOW_MED = 5, MED = 8, HIGH = 14}
local SNAPSHOT_NUM = 4
local LFO_NUM = 4
local SEQ_NUM = 8
local state = {
  held = nil,
  selectedSnapshot = 0,
}
local sequencers = {}
local clk = metro.init()
engine.name = "MollyThePoly"

local animator = {}
animator.clock = clk
animator.original = {}

local snapshots = {}

function copyTable(tbl)
  local copy = {}
  for k,v in pairs(tbl) do copy[k] = v end
  return copy
end

-- http://lua-users.org/wiki/CopyTable
function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
--    setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
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
    sequencers = options.sequencers,
    on = options.on,
    enabled = options.enabled,
  }

  return snapshot
end

local lfoTargets = {
  'none',
  'All Move X',
  'All Move Y',
}

local prevVal = 0


function lfo.process()
  local floor = math.floor

  for i=1,LFO_NUM do
    local target = params:get(i .. "lfo_target")

    if params:get(i .. 'lfo') == 2 then
      if target == 2 then handleMoveLFO(i, 'x', LENGTH)
      elseif target == 3 then handleMoveLFO(i, 'y', HEIGHT)
      end
    end
  end
end

function handleMoveLFO(index, axis, wrap)
  local val = 1

  if lfo[index].waveform == 'square' then
    val = math.floor(lfo.scale(lfo[index].slope, -1, 1, 1, wrap)) - 1
  else
    val = math.floor(lfo[index].slope * wrap + 0.5)
  end

  moveSequencersPos(axis, val, wrap)
  gridDraw()
  redraw()
end

function init()
  math.randomseed(os.time())
  for i=1,LFO_NUM do lfo[i].lfo_targets = lfoTargets end
  lfo.init()
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
  local numToFreq = MusicUtil.note_num_to_freq

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
    local note = animator.notes[pos]
    if #seqs > 1 then note = note + 12 end
    noteOn(note, numToFreq(note), math.random(127)/127)
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
      newOn[findPosition(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function moveStepsPos(index, axis, val, wrap)
  local steps = sequencers[index].steps
  clearStepState(steps)
  local newOn = {}

  local original = animator.original
  if not original[index] then original[index] = deepcopy(steps) end
  local originalSteps = original[index]
  local findPos = findPosition

  for i=1,#steps do
    local step = steps[i]
    local pos = findPos(step.x, step.y)
    step[axis] = (originalSteps[i][axis] + val - 1) % wrap + 1
    if on[pos] > 0 then
      newOn[findPos(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function moveSequencers(axis, delta, wrap)
  local newOn = {}
  for i=1,#sequencers do
    local resp = moveSteps(sequencers[i].steps, axis, delta, wrap)
    sequencers[i]:regenStepMap()
    for pos,n in pairs(resp) do newOn[pos] = n end
  end
  for pos,n in pairs(on) do
    if newOn[pos] ~= nil then
      on[pos] = enabled[pos]
    else
      on[pos] = 0
    end
  end
end

function moveSequencersPos(axis, val, wrap)
  local newOn = {}
  for i=1,#sequencers do
    local resp = moveStepsPos(i, axis, val, wrap)
    sequencers[i]:regenStepMap()
    for pos,n in pairs(resp) do newOn[pos] = n end
  end
  for pos,n in pairs(on) do
    if newOn[pos] ~= nil then
      on[pos] = enabled[pos]
    else
      on[pos] = 0
    end
  end
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
      snapshots[y] = Snapshot.new{on = on, enabled = enabled, sequencers = sequencers}
    end

    setToSnapshot(snapshots[y])
    gridDraw()
    redraw()
  end
end

function setToSnapshot(snapshot)
  on = copyTable(snapshot.on)
  enabled = copyTable(snapshot.enabled)
  sequencers = deepcopy(snapshot.sequencers)
end

function findOverlapIndex(posA, posB)
  for i=1,#sequencers do
    local stepMap = sequencers[i].stepMap
    if stepMap[posA] and stepMap[posB] then return i end
  end
end

function handleOverlap(pos, posHeld, index)
  local seq = sequencers[index]
  local steps = sequencers[index].steps
  local first = findPosition(steps[1].x, steps[1].y)
  local last = findPosition(steps[seq.length].x, steps[seq.length].y)

  if (pos == first and posHeld == last) or (posHeld == first and pos == last) then
    clearSeq(index)
    gridDraw()
    redraw()
    screen.clear()
  end
end

function mainSeqGridHandler(x, y)
  local held = state.held
  local posHeld
  if held ~= nil then
    posHeld = findPosition(held.x, held.y)
  end
  local pos = findPosition(x, y)

  if posHeld ~= nil then
    if enabled[posHeld] > 0 and enabled[pos] > 0 then
      local overlapIndex = findOverlapIndex(pos, posHeld)
      if overlapIndex ~= nil then
        return handleOverlap(pos, posHeld, overlapIndex)
      end
    end

    createNewSequence(x, y)
  else
    toggleStepOn(x, y)
    state.held = {x = x, y = y}
  end
  gridDraw()
  redraw()
  screen.clear()
end

function toggleStepOn(x, y)
  local pos = findPosition(x, y)
  if on[pos] > 0 then
    on[pos] = 0
  elseif enabled[pos] > 0 then
    on[pos] = enabled[pos]
  end
end

function createNewSequence(x, y)
  local steps = getNewLineSteps(state.held, {x = x, y = y})
  if steps ~= nil then
    sequencers[#sequencers+1] = Sequencer.new{steps = steps}
    updateEnabled(steps)
    updateOnState(steps)
    -- should this be here?
--    state.held = {x = x, y = y}
  end
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

  for i=1,SNAPSHOT_NUM do
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
      on[pos] = enabled[pos]
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
