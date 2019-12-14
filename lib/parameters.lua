local constants = include('animator/lib/constants')
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
local MusicUtil = require "musicutil"
local hs = include("awake/lib/halfsecond")

local parameters = {}

local H,L = constants.GRID_HEIGHT, constants.GRID_LENGTH
local STEP_NUM = H*L

function mapGridNotes(scale)
  local notes = {}
  local pointer = 0
  local intervals = MusicUtil.generate_scale(24, scale, 6)
  local startPos = STEP_NUM - L + 1
  local pos = startPos
  for i=1,H do
    for j=1,L do
      notes[pos] = intervals[pointer+j]
      pos = pos + 1
    end
    startPos = startPos - L
    pos = startPos
    pointer = pointer + 3
  end
  return notes
end

function parameters.init(animator)
  local hasMoveTarget = {[2] = true, [3] = true}

  for i=1,constants.LFO_NUM do
    params:set_action(i .. 'lfo',
      function(v)
        if v == 1 then
          local hasMove = false
          for j=1,4 do
            if j ~= i and hasMoveTarget[params:get(j .. 'lfo_target')] and params:get(j .. 'lfo') == 2 then
              hasMove = true
            end
          end

          if not hasMove then animator.original = {} end
        end
      end
    )
  end


  params:add_separator()
  animator.clock:add_clock_params()
  params:set('bpm', 80)

  params:add_separator()

  for i=1,8 do
    params:add_option('seq' .. i .. 'intersect', 'seq ' .. i .. ' intersect', {'octave', 'mute', 'reset all', 'reset self', 'reset other'}, 1)
    params:add_number('seq' .. i .. 'div', 'seq ' .. i .. ' clock div', 1, 8, 1)
    params:add_separator()
  end

  params:add_separator()

  params:add_option('scale', 'scale', {'major', 'minor'}, 2)
  params:set_action('scale', function(scale) animator.notes = mapGridNotes(scale) end)
  params:add_number('slop', 'slop', 0, 500, 0)
  params:add_number('max_notes', 'max notes', 1, 10, 6)
  params:add_separator()

  MollyThePoly.add_params()
  params:set('env_2_decay', 0.2)
  params:set('env_2_sustain', 0)
  params:set('env_2_release', 0.1)
  params:set('osc_wave_shape', 1)
  params:set('noise_level', 0)
  params:set('chorus_mix', 0)
--   hs.init()
end

return parameters
