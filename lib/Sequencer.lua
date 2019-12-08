local helpers = include('lib/helpers')
local Sequencer = {}
Sequencer.__index = Sequencer

function createStepMap(steps)
  local map = {}
  local findPos = helpers.findPosition
  for _,v in ipairs(steps) do
    map[findPos(v.x, v.y)] = 1
  end
  return map
end

function Sequencer.new(options)
  local seq = {
    ID = options.ID or os.time(),
    steps = options.steps,
    stepMap = createStepMap(options.steps),
    index = 1,
    length = #options.steps,
--    intersect = {MUTE, OCTAVE, RESET, RESET_GLOBAL},
    div = 1,
    divCount = 1,
  }

  setmetatable(seq, Sequencer)
  setmetatable(seq, {__index = Sequencer})

  return seq
end

function Sequencer:regenStepMap()
  self.stepMap = createStepMap(self.steps)
end

return Sequencer
