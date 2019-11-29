local GRID_HEIGHT, GRID_LENGTH = 8, 16
local MUTE, OCTAVE, RESET, RESET_GLOBAL, REVERSE, REPEL = 'mute', 'octave', 'reset', 'reset_global', 'reverse', 'repel'
local g = grid.connect()
local GRID_LEVELS = {DIM = 3, LOW_MED = 5, MED = 8, HIGH = 12}
local state = {held = nil}
local sequencers = {}
local mainClock = metro.init()
local MusicUtil = require "musicutil"

engine.name = 'PolyPerc'

function findPosition(x, y)
  return GRID_LENGTH * (y - 1) + x
end

function findXY(pos)
  return {x = (pos - 1) % GRID_LENGTH + 1, y = math.ceil(pos/GRID_LENGTH)}
end

-- function initOnMap()
--   local on = {}
--   for i=1,GRID_HEIGHT*GRID_LENGTH do on[i] = {} end
--   return on
-- end
-- -- for checking intersect
-- local on = initOnMap()

local on = {}

function initStepState()
  local steps = {}
  -- for checking can step be activated ie steps[128] = 1
  for i=1,GRID_HEIGHT*GRID_LENGTH do steps[i] = 0 end
  return steps
end

local stepState = initStepState()

local Sequencer = {}
Sequencer.__index = Sequencer

function Sequencer.new(steps)
  local seq = {
    ID = os.time() + math.random(999999),
    steps = steps, -- steps store positions on both axes
    index = 1, -- current step
    length = #steps,
    intersect = {MUTE, OCTAVE, REVERSE, REPEL, RESET, RESET_GLOBAL},
    div = 1,
    divCount = 1,
    xRate = 0, -- if ~= 0, move to right/left every xRate steps
    xRateCount = 1,
    yRate = 0,
    yRateCount = 1,
    metro = metro.init()
  }
  setmetatable(seq, Sequencer)
  setmetatable(seq, {__index = Sequencer})
  return seq
end

function Sequencer:createMetroEvent()
  return function() end
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
    startPos = startPos - 16
    pos = startPos
    pointer = pointer + 3
  end
  return notes
end

local notes = mapGridNotes()

function init()
  math.randomseed(os.time())
  g.key = gridKey
  mainClock.event = count
  mainClock:start()
  redraw()
end

function count()
  local play = {}
  for _,seq in ipairs(sequencers) do
    seq.index = seq.index % seq.length + 1
    local currentStep = seq.steps[seq.index]
    local pos = findPosition(currentStep.x, currentStep.y)
    if on[pos] == 1 then
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
    engine.hz(MusicUtil.note_num_to_freq(note))
  end
  gridDraw()
end

function redraw()
  screen.clear()
  screen.text('ANIMATOR')
  screen.update()
end

function key(n, z) end
function enc(n, delta) end

function gridKey(x, y, z)
  if z == 1 then
    handleGridKeyDown(x, y)
  else
    state.held = nil
  end
end

function handleGridKeyDown(x, y)
  if state.held ~= nil then
    local steps = getNewLineSteps(state.held, {x = x, y = y})
    table.insert(sequencers, Sequencer.new(steps))
    updateStepState(steps)
    state.held = {x = x, y = y}
  else
    if on[findPosition(x, y)] == 1 then
      on[findPosition(x, y)] = 0
    elseif stepState[findPosition(x, y)] == 1 then
      on[findPosition(x, y)] = 1
    end
    state.held = {x = x, y = y}
  end
  gridDraw()
end

function gridDraw()
  local steps = {}

  for _,seq in ipairs(sequencers) do
    local active = seq.steps[seq.index]
    local activePos = findPosition(active.x, active.y)
    if steps[activePos] == nil then steps[activePos] = {} end
    table.insert(steps[activePos], GRID_LEVELS.LOW_MED)

    for i,step in ipairs(seq.steps) do
      if i ~= seq.index then
        local inactivePos = findPosition(step.x, step.y)
        if steps[inactivePos] == nil then steps[inactivePos] = {} end
        table.insert(steps[inactivePos], GRID_LEVELS.DIM)
      end

      local enabledPos = findPosition(step.x, step.y)
      local isOn = on[enabledPos] == 1

      if isOn then
        if steps[enabledPos] == nil then steps[enabledPos] = {} end
        if i == seq.index then
          table.insert(steps[enabledPos], GRID_LEVELS.HIGH)
        else
          table.insert(steps[enabledPos], GRID_LEVELS.MED)
        end
      end
    end
  end

  for pos,levels in pairs(steps) do
    local step = findXY(pos)
    g:led(step.x, step.y, math.max(table.unpack(levels)))
  end
  g:refresh()
end

function updateStepState(steps)
  for _,step in ipairs(steps) do
    stepState[findPosition(step.x, step.y)] = 1
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
    -- else
    --   return getStepsJagged(a, b)
  end
end

function getStepsHorizontal(a, b)
  local steps = {}
  if a.x < b.x then
    for i = a.x, b.x do
      table.insert(steps, {x = i, y = a.y})
    end
    return steps
  else
    for i = a.x, b.x, -1 do
      table.insert(steps, {x = i, y = a.y})
    end
    return steps
  end
end

function getStepsVertical(a, b)
  local steps = {}
  if a.y < b.y then
    for i = a.y, b.y do
      table.insert(steps, {x = a.x, y = i})
    end
  else
    for i = a.y, b.y, -1 do
      table.insert(steps, {x = a.x, y = i})
    end
  end
  return steps
end

function getStepsDiagonal(a, b)
  local steps = {}
  local y = a.y

  if a.x < b.x then
    for i = a.x,b.x do
      table.insert(steps, {x = i, y = y})
      if a.y > b.y then
        y = y - 1
      else
        y = y + 1
      end
    end
  else
    for i = a.x,b.x,-1 do
      table.insert(steps, {x = i, y = y})
      if a.y > b.y then
        y = y - 1
      else
        y = y + 1
      end
    end
  end

  return steps
end

-- function getStepsJagged(a, b)
--   local steps = {}
--   -- local first
--   -- local last

--   -- if a.x < b.x then
--   --   first = a
--   --   last = b
--   -- else
--   --   first = b
--   --   last =  a
--   -- end

--   local x = a.x
--   local y = a.y

--   -- g:led(x, y, GRID_LEVELS.DIM)
--   table.insert(steps, {x = x, y = y})

--   while x ~= b.x or y ~= b.y do
--     if x ~= b.x and y ~= b.y then
--       if math.random(2) == 1 then
--         if x < b.x then
--           x = x + 1
--         else
--           x = x - 1
--         end
--       elseif y < b.y then
--         y = y + 1
--       else
--         y = y - 1
--       end
--     elseif x ~= b.x then
--       if x < b.x then
--         x = x + 1
--       else
--         x = x - 1
--       end
--     elseif y ~= b.y then
--       if y < b.y then
--         y = y + 1
--       else
--         y = y - 1
--       end
--     end
--     -- g:led(x, y, GRID_LEVELS.DIM)
--     table.insert(steps, {x = x, y = y})
--   end
--   return steps
-- end
