local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
local hs = include("awake/lib/halfsecond")
local parameters = {}

function parameters.init(animator)
  hs.init()
  params:add_number('tempo', 'tempo', 20, 999, 120)
  params:set_action('tempo', function(v) animator.clock.time = 60 / v end)
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
