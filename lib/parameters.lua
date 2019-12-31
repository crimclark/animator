local constants = include('animator/lib/constants')
local INTERSECT_OPS = constants.INTERSECT_OPS
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
local MusicUtil = require "musicutil"
local lfo = include('animator/lib/lfo')

local parameters = {}

local H,L = constants.GRID_HEIGHT, constants.GRID_LENGTH
local STEP_NUM = H*L

function mapGridNotes(scale, transpose)
  local notes = {}
  local pointer = 0
  local intervals = MusicUtil.generate_scale(24 + transpose, scale, 6)
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

function getScaleNames()
  local names = {}
  local scales = MusicUtil.SCALES
  for i=1,#scales do
    names[#names+1] = scales[i].name
  end
  return names
end

function addSeqParams(animator)
  for i=1,8 do
    params:add_option('seq' .. i .. 'intersect', 'seq ' .. i .. ' intersect', INTERSECT_OPS, 1)
    params:set_action('seq' .. i .. 'intersect', function(v)
      if animator.sequencers[i] then
        animator.sequencers[i].intersect = v
      end
    end)

    params:add_number('seq' .. i .. 'div', 'seq ' .. i .. ' clock div', 1, 8, 1)
    params:set_action('seq' .. i .. 'div', function(v)
      if animator.sequencers[i] then
        animator.sequencers[i].div = v
      end
    end)

    params:add_number('seq' .. i .. 'channel', 'seq ' .. i .. ' midi ch', 1, 16, 1)
    params:set_action('seq' .. i .. 'channel', function(v)
      if animator.sequencers[i] then
        animator.sequencers[i].channel = v
      end
    end)
    params:add_separator()
  end
end

function parameters.init(animator)
  params:add_option('output', 'output', constants.OUTPUTS, 1)
  params:add_number('midi_out_device', 'midi out device', 1, 4, 1)
  params:set_action('midi_out_device', function(v) animator.midiOut = midi.connect(v) end)

  animator.clock:add_clock_params()
  params:set('bpm', 80)

  local noteLengthControlspec = controlspec.new(0.01, 1, 'lin', 0.01, 0.01, "")
  params:add_control('min_note_length', 'min note length', noteLengthControlspec)
  params:add_control('max_note_length', 'max note length', noteLengthControlspec)
  params:set_action('min_note_length', function(v)
    if v > params:get('max_note_length') then
      params:set('max_note_length', v)
    end
  end)

  params:add_number('max_velocity', 'max velocity', 1, 127, 127)
  params:add_number('min_velocity', 'min velocity', 1, 127, 1)
  params:set_action('min_velocity', function(v)
    if v > params:get('max_velocity') then
      params:set('max_velocity', v)
    end
  end)
  params:add_option('scale', 'scale', getScaleNames(), 1)
  params:set_action('scale', function(scale)
    animator.notes = mapGridNotes(scale, params:get('global_transpose'))
  end)
  params:add_number('global_transpose', 'global transpose', -12, 12, 0)
  params:set_action('global_transpose', function(v)
    animator.notes = mapGridNotes(params:get('scale'), v)
  end)
  params:add_number('slop', 'slop', 0, 500, 0)
  params:add_number('max_notes', 'max notes', 1, 10, 6)

  lfo.init(animator)

  local hasMoveTarget = {[2] = true, [3] = true}

  for i=1,constants.LFO_NUM do
    params:set_action(i .. 'lfo',
      function(v)
        if v == 1 then
          local hasMove = false
          for j=1,constants.LFO_NUM do
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

  MollyThePoly.add_params()
  params:set('env_2_decay', 0.2)
  params:set('env_2_sustain', 0)
  params:set('env_2_release', 0.1)
  params:set('osc_wave_shape', 1)
  params:set('noise_level', 0)
  params:set('chorus_mix', 0)

  params:add_separator()

  addSeqParams(animator)
end

return parameters
