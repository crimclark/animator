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
  hs.init()
  params:add_number('tempo', 'tempo', 20, 999, 120)
  params:set_action('tempo', function(v) animator.clock.time = 60 / v end)

  params:add_option('scale', 'scale', {'major', 'minor'}, 2)
  params:set_action('scale', function(scale) animator.notes = mapGridNotes(scale) end)

  MollyThePoly.add_params()
  params:set('env_2_decay', 0.2)
  params:set('env_2_sustain', 0)
  params:set('env_2_release', 0.1)
  params:set('osc_wave_shape', 1)
  params:set('noise_level', 0)
  params:set('chorus_mix', 0)
  params:set('delay_rate', 1.333)
end

return parameters
