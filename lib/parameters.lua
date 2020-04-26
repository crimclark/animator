local fileselect = require 'fileselect'
local textentry = require 'textentry'
local constants = include('animator/lib/constants')
local INTERSECT_OPS = constants.INTERSECT_OPS
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
local MusicUtil = require "musicutil"
local lfo = include('animator/lib/lfo')

local parameters = {}

local H,L = constants.CANVAS_HEIGHT, constants.CANVAS_LENGTH
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
  local internal = 'internal'
  params:add_group(internal, 16)
  params:hide(internal)
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
  end
end

function parameters.init(animator)
  params:add_separator('ANIMATOR')
  params:add_group('SAVE/LOAD', 2)
  params:add_trigger('save', 'save doodle')
  params:set_action('save', function(x) textentry.enter(animator.save, animator.name) end)
  params:add_trigger('load', 'load doodle')
  params:set_action('load', function() fileselect.enter(norns.state.data, animator.load) end)

  params:add_group('SETTINGS', 7)
  params:add_option('output', 'output', constants.OUTPUTS, 1)
  params:set_action('output', function(v)
    local output = constants.OUTPUTS[v]
    local triggerASL = '{to(5,0),to(0,0.25)}'

    if output == constants.OUTPUT_AUDIO or output == constants.OUTPUT_AUDIO_MIDI or output == constants.OUTPUT_MIDI then
      crow.ii.jf.mode(0)
    elseif output == constants.OUTPUT_CROW_CV then
      crow.ii.jf.mode(0)
      crow.output[2].action = triggerASL
      crow.output[4].action = triggerASL
    elseif output == constants.OUTPUT_CROW_II_JF then
      crow.ii.jf.mode(1)
    elseif output == constants.OUTPUT_CROW_CV_JF or output == constants.OUTPUT_AUDIO_CV_JF then
      crow.ii.jf.mode(1)
      crow.output[2].action = triggerASL
      crow.output[4].action = triggerASL
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
  params:add_option('quantize', 'pattern quantize', {'off', 'on'}, 2)
  params:add_number('quant_div', 'quantization div', 1, 8, 1)
  params:add_number('slop', 'slop', 0, 500, 0)
  params:add_number('max_notes', 'max notes', 1, 10, 6)

  params:add_group('MIDI', 13)
  params:add_number('midi_out_device', 'midi out device', 1, 4, 1)
  params:set_action('midi_out_device', function(v) animator.midiOut = midi.connect(v) end)
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
  for i=1,8 do
    params:add_number('seq' .. i .. 'channel', 'seq ' .. i .. ' midi ch', 1, 16, 1)
    params:set_action('seq' .. i .. 'channel', function(v)
      if animator.sequencers[i] then
        animator.sequencers[i].channel = v
      end
    end)
  end

  params:add_group('LFO', 14)
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

  params:add_group('SYNTH', 47)

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
