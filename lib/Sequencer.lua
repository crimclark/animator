local helpers = include('lib/helpers')
local Sequencer = {}
Sequencer.__index = Sequencer

function createStepMap(steps)
  local map = {}
  local findPos = helpers.findPosition
  for _,v in ipairs(steps) do
    map[findPos(v.x, v.y)] = true
  end
  return map
end

function Sequencer.new(options, position)
  local seq = {
    steps = options.steps,
    stepMap = createStepMap(options.steps),
    index = options.index or 1, -- current step index
    length = #options.steps,
    intersect = params:get('seq' .. position .. 'intersect'),
    div = params:get('seq' .. position .. 'div'),
    divCount = options.divCount or 1,
    reset = options.reset or false,
    channel = params:get('seq' .. position .. 'channel'),
  }

  setmetatable(seq, Sequencer)
  setmetatable(seq, {__index = Sequencer})

  return seq
end

function Sequencer:regenStepMap()
  self.stepMap = createStepMap(self.steps)
end

return Sequencer
