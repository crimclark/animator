local GRID_HEIGHT, GRID_LENGTH = 8, 16
local MUTE, OCTAVE, RESET, RESET_GLOBAL = 'mute', 'octave', 'reset', 'reset_global'
local g = grid.connect()
local GRID_LEVELS = {DIM = 2, LOW_MED = 4, MED = 8, HIGH = 14}
local state = {
  held = nil,
  moveSeq = false,
}
local sequencers = {}
local mainClock = metro.init()
local MusicUtil = require "musicutil"
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
local hs = include("awake/lib/halfsecond")
engine.name = "MollyThePoly"

function findPosition(x, y)
  return GRID_LENGTH * (y - 1) + x
end

function findXY(pos)
  return {x = (pos - 1) % GRID_LENGTH + 1, y = math.ceil(pos/GRID_LENGTH)}
end

function initStepState()
  local steps = {}
  -- for checking can step be activated ie steps[128] = 1
  for i=1,GRID_HEIGHT*GRID_LENGTH do steps[i] = 0 end
  return steps
end

local on = initStepState()
local stepState = initStepState()

local Sequencer = {}
Sequencer.__index = Sequencer

function Sequencer.new(steps)
  local seq = {
    ID = os.time() + math.random(999999),
    steps = steps, -- steps store positions on both axes
    index = 1, -- current step
    length = #steps,
    intersect = {MUTE, OCTAVE, RESET, RESET_GLOBAL},
    div = 1,
    divCount = 1,
    xRate = 0, -- if ~= 0, move to right/left every xRate steps
    xRateCount = 1,
    yRate = 0,
    yRateCount = 1,
  }
  setmetatable(seq, Sequencer)
  setmetatable(seq, {__index = Sequencer})
  return seq
end

function mapGridNotes()
  local notes = {}
  local pointer = 0
  local intervals = MusicUtil.generate_scale(24, 'major', 6)
  local stepNum = GRID_HEIGHT*GRID_LENGTH
  local startPos = stepNum - GRID_LENGTH + 1
  local pos = startPos
  for i=1,GRID_HEIGHT do
    for j=1,GRID_LENGTH do
      notes[pos] = intervals[pointer+j]
      pos = pos + 1
    end
    startPos = startPos - GRID_LENGTH
    pos = startPos
    pointer = pointer + 3
  end
  return notes
end

local notes = mapGridNotes()

function init()
  initParams()
  math.randomseed(os.time())
  g.key = gridKey
  mainClock.event = count
  mainClock:start()
  hs.init()
  params:set('delay_rate', 1.333)
  redraw()
end

function initParams()
  params:add_number('tempo', 'tempo', 20, 999, 120)
  params:set_action('tempo', function(v) mainClock.time = 60 / v end)
  MollyThePoly.add_params()
  params:set('env_2_decay', 0.2)
  params:set('env_2_sustain', 0)
  params:set('env_2_release', 0.1)
  params:set('osc_wave_shape', 1)
  params:set('noise_level', 0)
  params:set('chorus_mix', 0)
end

function count()
  local play = {}
  for _,seq in ipairs(sequencers) do
    seq.index = seq.index % seq.length + 1
    local currentStep = seq.steps[seq.index]
    local pos = findPosition(currentStep.x, currentStep.y)
    if on[pos] > 0 then
      if play[pos] == nil then
        play[pos] = {seq.ID}
      else
        table.insert(play[pos], seq.ID)
      end
    end
  end

  for pos,seqs in pairs(play) do
    local note = notes[pos]
    if #seqs > 1 then note = note + 12 end
    engine.noteOn(note, MusicUtil.note_num_to_freq(note), 1)
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

function moveSteps(steps, axis, delta, wrapLength)
  clearStepState(steps)
  local newOn = {}

  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    step[axis] = (step[axis] + delta - 1) % wrapLength + 1
    if on[pos] > 0 then
--      table.insert(oldOn, pos)
      newOn[pos] = -1
      local newPos = findPosition(step.x, step.y)
      newOn[newPos] = 1
--      table.insert(newOn, newPos)
    end
  end

  updateStepState(steps)
  return newOn
end

function enc(n, delta)
  local newOn = {}
  if n == 3 then
    for i=1,#sequencers do
      local resp = moveSteps(sequencers[i].steps, 'x', delta, GRID_LENGTH)
      for pos,n in pairs(resp) do
        if newOn[pos] == nil then
          newOn[pos] = n
        else newOn[pos] = newOn[pos] + n
        end
      end
    end
    gridDraw()
    redraw()
  end
  if n == 2 then
    for i=1,#sequencers do
      local resp = moveSteps(sequencers[i].steps, 'y', delta, GRID_HEIGHT)
      for pos,n in pairs(resp) do
        if newOn[pos] == nil then
          newOn[pos] = n
        else newOn[pos] = newOn[pos] + n
        end
      end
    end
    gridDraw()
    redraw()
  end

  for pos,n in pairs(newOn) do
    on[pos] = on[pos] + n
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
      table.insert(sequencers, Sequencer.new(steps))
      updateStepState(steps)
      updateOnState(steps)
      state.held = {x = x, y = y}
    end
  else
    local pos = findPosition(x, y)
    if on[pos] > 0 then
      on[pos] = 0
    elseif stepState[pos] > 0 then
      -- set on to same number of enabled at position
      on[pos] = stepState[pos]
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
  local steps = {}
  for _,seq in ipairs(sequencers) do
    for i,step in ipairs(seq.steps) do
      local pos = findPosition(step.x, step.y)
      -- step activated
      if on[pos] > 0 then
        if i == seq.index then
          steps[pos] = GRID_LEVELS.HIGH
        else
          steps[pos] = steps[pos] == nil
            and GRID_LEVELS.MED
            or math.max(steps[pos], GRID_LEVELS.MED)
        end
      -- step highlighted but not activated
      elseif i == seq.index then
        steps[pos] = steps[pos] == nil
          and GRID_LEVELS.LOW_MED
          or math.max(steps[pos], GRID_LEVELS.LOW_MED)
      -- step not highlighted or activated
      else
        steps[pos] = steps[pos] == nil
          and GRID_LEVELS.DIM
          or math.max(steps[pos], GRID_LEVELS.DIM)
      end
    end
  end
  return steps
end

function screenDrawSteps()
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
  for pos,level in pairs(getStepLevels()) do
    local step = findXY(pos)
    g:led(step.x, step.y, level)
  end
  g:refresh()
end

function updateStepState(steps)
  for _,step in ipairs(steps) do
    local pos = findPosition(step.x, step.y)
    stepState[pos] = stepState[pos] + 1
  end
end

function updateOnState(steps)
  for _,step in ipairs(steps) do
    local pos = findPosition(step.x, step.y)
    if on[pos] > 0 then
      on[pos] = on[pos] + 1
    end
  end
end

function clearStepState(steps)
  for _,step in ipairs(steps) do
    local pos = findPosition(step.x, step.y)
    stepState[pos] = stepState[pos] - 1
  end
end

function clearOnState(steps)
  for _,step in ipairs(steps) do
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
      table.insert(steps, {x = i, y = a.y, on = 0})
    end
    return steps
  else
    for i = a.x, b.x, -1 do
      table.insert(steps, {x = i, y = a.y, on = 0})
    end
    return steps
  end
end

function getStepsVertical(a, b)
  local steps = {}
  if a.y < b.y then
    for i = a.y, b.y do
      table.insert(steps, {x = a.x, y = i, on = 0})
    end
  else
    for i = a.y, b.y, -1 do
      table.insert(steps, {x = a.x, y = i, on = 0})
    end
  end
  return steps
end

function getStepsDiagonal(a, b)
  local steps = {}
  local y = a.y

  if a.x < b.x then
    for i = a.x,b.x do
      table.insert(steps, {x = i, y = y, on = 0})
      if a.y > b.y then
        y = y - 1
      else
        y = y + 1
      end
    end
  else
    for i = a.x,b.x,-1 do
      table.insert(steps, {x = i, y = y, on = 0})
      if a.y > b.y then
        y = y - 1
      else
        y = y + 1
      end
    end
  end

  return steps
end
