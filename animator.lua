local GRID_LENGTH = 16

function findPosition(x, y) 
  return GRID_LENGTH * (y - 1) + x
end

function findXY(pos)
  return {(pos - 1) % GRID_LENGTH + 1, math.ceil(pos/GRID_LENGTH)}
end

local seq = {
  ID = os.time(),
  steps = {128, 127, 150}, -- steps store positions on both axes
  index = 1, -- current step
  intersect = {'mute', 'octave', 'reset', 'reverse'},
  div = 1,
  divCount = 1,
  xRate = 0, -- if ~= 0, move to right/left every xRate steps
  xRateCount = 1, 
  yRate = 0,
  yRateCount = 1,
  metro 
}

-- on metro count, iterate through sequences and check if position[sequenceID] in enabled table

local enabled = {150 = {sequences[1].ID, sequences[3].ID}}

-- if enabled, check sequences with other IDs for POS if have same current position, if true, check "intersect behavior" 
-- associated with each sequence and play note or some other event, else just play note
