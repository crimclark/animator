local GRID_HEIGHT, GRID_LENGTH = 8, 16
local MUTE, OCTAVE, RESET, RESET_GLOBAL, REVERSE, REPEL = 'mute', 'octave', 'reset', 'reset_global', 'reverse', 'repel'
local state = {held = nil}

function findPosition(x, y)
  return GRID_LENGTH * (y - 1) + x
end

function findXY(pos)
  return {(pos - 1) % GRID_LENGTH + 1, math.ceil(pos/GRID_LENGTH)}
end

function initOnMap()
  local on = {}
  for i=1,GRID_HEIGHT*GRID_LENGTH do on[i] = {} end
  return on
end

local on = initOnMap()

local Sequencer = {}
Sequencer.__index = Sequencer

function Sequencer.new()
  local seq = {
    ID = os.time() + math.random(9999999999),
    steps = {}, -- steps store positions on both axes
    index = 1, -- current step
    intersect = {MUTE, OCTAVE, REVERSE, REPEL, RESET, RESET_GLOBAL},
    div = 1,
    divCount = 1,
    xRate = 0, -- if ~= 0, move to right/left every xRate steps
    xRateCount = 1,
    yRate = 0,
    yRateCount = 1,
    metro = metro.init()
  }
  seq.metro.event = seq:createMetroEvent()
  setmetatable(seq, Sequencer)
  setmetatable(seq, {__index = Sequencer})
  return seq
end

function Sequencer:createMetroEvent()
  return function() end
end


-- on metro count, iterate through sequences and check if position[sequenceID] in enabled table
--local enabled = {150 = {sequences[1].ID, sequences[3].ID}}

-- if enabled, check sequences with other IDs for POS if have same current position, if true, check "intersect behavior"
-- associated with each sequence and play note or some other event, else just play note

function init() end

function redraw() end

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
    -- create seq from held to pos
  else
    state.held = {x = x, y = y}
  end
end
