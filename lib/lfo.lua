local constants = include('lib/constants')
local hnds = include('lib/hnds')
local LFO_NUM = 4
local lfo = {}

function createProcess(handlers)
  return function()
    local floor = math.floor

    for i=1,LFO_NUM do
      local target = params:get(i .. 'lfo_target')

      if params:get(i .. 'lfo') == 2 and target ~= 1 then
        handlers[target](i)
      end
    end
  end
end

function setLfoTargets()
  local targets = {
    'none',
    'All Move X',
    'All Move Y',
  }

  for i=1,LFO_NUM do hnds[i].lfo_targets = targets end
end

function createLfoHandlers(animator)
  local function handleMove(index, axis, wrap)
    local val = 0

    if hnds[index].waveform == 'square' then
      val = math.floor(hnds.scale(hnds[index].slope, -1, 1, 1, wrap)) - 1
    else
      val = math.floor(hnds[index].slope * wrap + 0.5)
    end

    animator.moveSequencersPos(axis, val, wrap)
    animator.redraw()
  end

  local handlers = {}
  handlers[1] = function() end
  handlers[2] = function(i) handleMove(i, 'x', constants.GRID_LENGTH) end
  handlers[3] = function(i) handleMove(i, 'y', constants.GRID_HEIGHT) end

  return handlers
end

function lfo.init(animator)
  setLfoTargets()
  hnds.process = createProcess(createLfoHandlers(animator))
  hnds.init()
end

return lfo
