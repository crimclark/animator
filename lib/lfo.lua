local constants = include('lib/constants')
local hnds = include('lib/hnds')
local LFO_NUM = 4
local lfo = {}

local lfoTargets = {
  'none',
  'All Move X',
  'All Move Y',
}

function createProcess(handlers)
  return function()
    local floor = math.floor

    for i=1,LFO_NUM do
      local target = params:get(i .. "lfo_target")

      if params:get(i .. 'lfo') == 2 and target ~= 1 then
        handlers[target](i)
      end
    end
  end
end

function lfo.init(animator)
  local move = animator.moveSequencersPos
  local draw = animator.drawAll
  local floor = math.floor
  local scale = hnds.scale

  local function handleMoveLFO(index, axis, wrap)
    local val = 1

    if hnds[index].waveform == 'square' then
      val = floor(scale(hnds[index].slope, -1, 1, 1, wrap)) - 1
    else
      val = floor(hnds[index].slope * wrap + 0.5)
    end

    move(axis, val, wrap)
    draw()
  end

  local lfoHandlers = {}
  lfoHandlers[1] = function() end
  lfoHandlers[2] = function(i) handleMoveLFO(i, 'x', constants.GRID_LENGTH) end
  lfoHandlers[3] = function(i) handleMoveLFO(i, 'y', constants.GRID_HEIGHT) end
  for i=1,LFO_NUM do hnds[i].lfo_targets = lfoTargets end
  hnds.process = createProcess(lfoHandlers)

  hnds.init()
end

return lfo
