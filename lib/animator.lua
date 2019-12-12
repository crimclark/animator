local constants = include('lib/constants')
local STEP_NUM = constants.GRID_HEIGHT*constants.GRID_LENGTH
local helpers = include('lib/helpers')
local findPosition = helpers.findPosition
local copyTable = helpers.copyTable
local deepcopy = helpers.deepcopy
local Sequencer = include('lib/Sequencer')
local MusicUtil = require 'musicutil'
local GRID_LEVELS = {DIM = 3, LOW_MED = 5, MED = 8, HIGH = 14}
local clock = metro.init()

function initStepState()
  local steps = {}
  for i=1,STEP_NUM do steps[i] = 0 end
  return steps
end

local animator = {}

animator.clock = clock
animator.original = {}
animator.stepLevels = {}
animator.redraw = function() end
animator.on = initStepState()
animator.enabled = initStepState()
animator.sequencers = {}
animator.snapshots = {}

function updateEnabled(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    animator.enabled[pos] = animator.enabled[pos] + 1
  end
end

function updateOnState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    if animator.on[pos] > 0 then
      animator.on[pos] = animator.enabled[pos]
    end
  end
end

function animator.createNewSequence(x, y)
  local steps = getNewLineSteps(animator.grid.held, {x = x, y = y})
  if steps ~= nil then
    animator.sequencers[#animator.sequencers+1] = Sequencer.new{steps = steps}
    updateEnabled(steps)
    updateOnState(steps)
    -- should this be here?
--    state.held = {x = x, y = y}
  end
end

function animator.toggleStepOn(x, y)
  local pos = findPosition(x, y)
  if animator.on[pos] > 0 then
    animator.on[pos] = 0
  elseif animator.enabled[pos] > 0 then
    animator.on[pos] = animator.enabled[pos]
  end
end

local Snapshot = {}
function Snapshot.new(animator)
  local snapshot = {
    sequencers = animator.sequencers,
    on = animator.on,
    enabled = animator.enabled,
  }

  return snapshot
end

function animator.count()
  local play = {}
  local findPos = findPosition
  local noteOn = engine.noteOn
  local numToFreq = MusicUtil.note_num_to_freq
  local random = math.random
  local slop = params:get('slop')
  local metroInit = metro.init

  local function playNote(note)
    noteOn(note, numToFreq(note), random(127)/127)
  end

  local function delayNote(note)
    local delay = metroInit()
    delay.event = function()
      playNote(note)
      metro.free(delay.id)
    end
    delay.time = random(slop)/100
    delay.count = 1
    delay:start()
  end

  for i=1,#animator.sequencers do
    local seq = animator.sequencers[i]
    seq.index = seq.index % seq.length + 1
    local currentStep = seq.steps[seq.index]
    local pos = findPos(currentStep.x, currentStep.y)
    if animator.on[pos] > 0 then
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

    if slop > 0 then
      delayNote(note)
    else
      playNote(note)
    end
  end
  animator.redraw()
end

function moveSteps(steps, axis, delta, wrap)
  clearStepState(steps)
  local newOn = {}

  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    step[axis] = (step[axis] + delta - 1) % wrap + 1
    if animator.on[pos] > 0 then
      newOn[findPosition(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function moveStepsPos(index, axis, val, wrap)
  local steps = animator.sequencers[index].steps
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
    if animator.on[pos] > 0 then
      newOn[pos] = -1
      newOn[findPos(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function animator.moveSequencers(axis, delta, wrap)
  local newOn = {}
  for i=1,#animator.sequencers do
    local resp = moveSteps(animator.sequencers[i].steps, axis, delta, wrap)
    animator.sequencers[i]:regenStepMap()
    for pos,n in pairs(resp) do newOn[pos] = n end
  end
  for pos,n in pairs(animator.on) do
    if newOn[pos] ~= nil then
      animator.on[pos] = animator.enabled[pos]
    else
      animator.on[pos] = 0
    end
  end
end

function animator.moveSequencersPos(axis, val, wrap)
  local newOn = {}
  for i=1,#animator.sequencers do
    local resp = moveStepsPos(i, axis, val, wrap)
    animator.sequencers[i]:regenStepMap()
    for pos,n in pairs(resp) do newOn[pos] = n end
  end
  for pos,n in pairs(animator.on) do
    if newOn[pos] == 1 then
      animator.on[pos] = animator.enabled[pos]
    else
      animator.on[pos] = 0
    end
  end
end

function animator.handleNavSelect(y)
  if y >= 1 and y <= 4 then
    animator.grid.snapshot = y

    if animator.snapshots[y] == nil then
      animator.snapshots[y] = Snapshot.new(animator)
    end

    setToSnapshot(animator.snapshots[y])
    animator.redraw()
  end
end

function setToSnapshot(snapshot)
  animator.on = copyTable(snapshot.on)
  animator.enabled = copyTable(snapshot.enabled)
  animator.sequencers = deepcopy(snapshot.sequencers)
end

function animator.clearSeq(index)
  clearStepState(animator.sequencers[index].steps)
  clearOnState(animator.sequencers[index].steps)
  table.remove(animator.sequencers, index)
end

function animator.resetStepLevels()
  animator.stepLevels = getStepLevels()
end

function getStepLevels()
  local levels = {}
  local findPos = findPosition
  local max = math.max
  for i=1,#animator.sequencers do
    local seq = animator.sequencers[i]
    local steps = seq.steps
    for i=1,#steps do
      local step = steps[i]
      local pos = findPos(step.x, step.y)
      -- step activated
      if animator.on[pos] > 0 then
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

function clearStepState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    animator.enabled[pos] = animator.enabled[pos] - 1
  end
end

function clearOnState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    if animator.on[pos] > 0 then
      animator.on[pos] = animator.on[pos] - 1
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

return animator
