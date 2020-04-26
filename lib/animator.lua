local tab = require 'tabutil'
local constants = include('lib/constants')
local STEP_NUM = constants.CANVAS_HEIGHT*constants.CANVAS_LENGTH
local GRID_LEVELS = constants.GRID_LEVELS
local INTERSECT_OPS = constants.INTERSECT_OPS
local OUTPUTS = constants.OUTPUTS
local AUDIO = constants.OUTPUT_AUDIO
local MIDI = constants.OUTPUT_MIDI
local AUDIO_MIDI = constants.OUTPUT_AUDIO_MIDI
local CROW_II_JF = constants.OUTPUT_CROW_II_JF
local CROW_CV = constants.OUTPUT_CROW_CV
local CROW_CV_JF = constants.OUTPUT_CROW_CV_JF
local AUDIO_CV_JF = constants.OUTPUT_AUDIO_CV_JF
local helpers = include('lib/helpers')
local findPosition = helpers.findPosition
local copyTable = helpers.copyTable
local deepcopy = helpers.deepcopy
local Sequencer = include('lib/Sequencer')
local MusicUtil = require 'musicutil'
local MAX_SEQ_NUM = 8

function initStepState()
  local steps = {}
  for i=1,STEP_NUM do steps[i] = 0 end
  return steps
end

local animator = {}

animator.noteOffMetro = metro.init()
animator.original = {}
animator.stepLevels = {}
animator.redraw = function() end
animator.on = initStepState()
animator.enabled = initStepState()
animator.sequencers = {}
animator.snapshots = {}
animator.shouldResetAll = false
animator.lastReplaced = 0
animator.showIntroText = true
animator.midiDevice = nil
animator.name = 'untilted'

function updateEnabled(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    animator.enabled[pos] = animator.enabled[pos] + 1
  end
end

function updateOnState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    if animator.on[pos] > 0 then
      animator.on[pos] = animator.enabled[pos]
    end
  end
end

function animator.addNewSequence(steps)
  local index
  if #animator.sequencers == MAX_SEQ_NUM then
    animator.lastReplaced = animator.lastReplaced % MAX_SEQ_NUM + 1
    index = animator.lastReplaced
  else
    index = #animator.sequencers+1
  end
  if animator.showIntroText then animator.showIntroText = false end
  animator.sequencers[index] = Sequencer.new{steps = steps, index = index}
  updateEnabled(steps)
  updateOnState(steps)
end

local Snapshot = {}
function Snapshot.new(animator)
  local snapshot = {
    sequencers = animator.sequencers,
    on = animator.on,
    enabled = animator.enabled,
    divs = {},
    intersects = {}
  }
  for i=1,MAX_SEQ_NUM do
    snapshot.divs[i] = params:get('seq' .. i .. 'div')
    snapshot.intersects[i] = params:get('seq' .. i .. 'intersect')
  end

  return snapshot
end

function animator.count()
  local play = {}
  local findPos = findPosition
  local noteOn = engine.noteOn
  local noteOff = engine.noteOff
  local numToFreq = MusicUtil.note_num_to_freq
  local random = math.random
  local slop = params:get('slop')
  local minVel = params:get('min_velocity')
  local maxVel = params:get('max_velocity')
  local minLn = params:get('min_note_length')
  local maxLn = params:get('max_note_length')
  local metroInit = metro.init
  local metroFree = metro.free
  local output = OUTPUTS[params:get('output')]
  local jfPlayNote = crow.ii.jf.play_note

  local useMidiCheck = {[MIDI] = true, [AUDIO_MIDI] = true}
  local useMidi = useMidiCheck[output]

  local useAudioCheck = {[AUDIO] = true, [AUDIO_MIDI] = true, [AUDIO_CV_JF] = true}
  local useAudio = useAudioCheck[output]

  local useJFCheck = {[CROW_II_JF] = true, [CROW_CV_JF] = true, [AUDIO_CV_JF] = true}
  local useJF = useJFCheck[output]

  local useCVCheck = {[CROW_CV] = true, [CROW_CV_JF] = true, [AUDIO_CV_JF] = true}
  local useCV = useCVCheck[output]

  local currentCrowOut = 1
  local crowCVPlayed = 0

  local function playNote(note, channel)
    if useJF then
      jfPlayNote((note-60)/12, 5)
    end

    if useCV and crowCVPlayed < 2 then
      crow.output[currentCrowOut].volts = (note-60)/12
      crow.output[currentCrowOut+1].execute()
      currentCrowOut = (currentCrowOut + 2) % 4
      crowCVPlayed = crowCVPlayed + 1
    end

    if useAudio or useMidi then
      local velocity = random(minVel, maxVel)

      if useMidi then animator.midiDevice:note_on(note, velocity, channel) end
      if useAudio then
        noteOn(note, numToFreq(note), velocity/127)
      end

      local noteOffMetro = metroInit()
      noteOffMetro.event = function()
        if useMidi then animator.midiDevice:note_off(note, nil, channel) end
        if useAudio then noteOff(note) end
        metroFree(noteOffMetro.id)
      end
      noteOffMetro.time = random(minLn*100, maxLn*100)/100
      noteOffMetro.count = 1
      noteOffMetro:start()
    end
  end

  local function delayNote(note, channel)
    local delay = metroInit()
    delay.event = function()
      playNote(note, channel)
      metroFree(delay.id)
    end
    delay.time = random(slop)/1000
    delay.count = 1
    delay:start()
  end

  for i=1,#animator.sequencers do
    local seq = animator.sequencers[i]
    seq.divCount = seq.divCount % seq.div + 1
    if seq.divCount == 1 then
      seq.index = seq.index % seq.length + 1
      if animator.shouldResetAll then
        seq.index = 1
      end
      if seq.reset then
        seq.index = 1
        seq.reset = false
      end
      local currentStep = seq.steps[seq.index]
      local pos = findPos(currentStep.x, currentStep.y)
      if animator.on[pos] > 0 then
        if play[pos] == nil then
          play[pos] = {seq}
        else
          play[pos][#play[pos]+1] = seq
        end
      end
    end
  end

  if animator.shouldResetAll then animator.shouldResetAll = false end

  local maxNotes = params:get('max_notes')
  local noteCount = 0
  local notesPlayed = {}
  local channelNotes = {}

  for pos,seqs in pairs(play) do
    local note = animator.notes[pos]
    local channel = seqs[1].channel
    local channelNotes = {}
    channelNotes[channel] = note
    local mute = false
    local seqNum = #seqs
    if seqNum > 1 then
      for i=1,seqNum do
        local intersect = INTERSECT_OPS[seqs[i].intersect]
        if intersect == constants.INTERSECT_OP_OCTAVE then
          note = note + 12
        elseif intersect == constants.INTERSECT_OP_MUTE then
          mute = true
        elseif intersect == constants.INTERSECT_OP_RESET_SELF then
          seqs[i].reset = true
        elseif intersect == constants.INTERSECT_OP_RESET_OTHER then
          for j=1,seqNum do if j~= i then seqs[j].reset = true end end
        elseif intersect == constants.INTERSECT_OP_RESET_ALL then
          animator.shouldResetAll = true
        end
        channelNotes[seqs[i].channel] = note
      end
    end

    for channel,note in pairs(channelNotes) do
      if not mute and notesPlayed[note] ~= channel then
        if slop > 0 then
          delayNote(note, channel)
        else
          playNote(note, channel)
        end
        notesPlayed[note] = channel
        noteCount = noteCount+1
        if noteCount == maxNotes then
          return animator.redraw()
        end
      end
    end
  end

  animator.redraw()
end

function moveSteps(steps, axis, delta, wrap)
  clearStepState(steps)
  local newOn = {}

  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    step[axis] = (step[axis] + delta - 1) % wrap + 1
    if animator.on[pos] > 0 then
      newOn[findPosition(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function moveStepsPos(index, axis, val, wrap)
  local steps = animator.sequencers[index].steps
  clearStepState(steps)
  local newOn = {}

  local original = animator.original
  if not original[index] then original[index] = deepcopy(steps) end
  local originalSteps = original[index]
  local findPos = findPosition

  for i=1,#steps do
    local step = steps[i]
    local pos = findPos(step.x, step.y)
    step[axis] = (originalSteps[i][axis] + val - 1) % wrap + 1
    if animator.on[pos] > 0 then
      newOn[findPosition(step.x, step.y)] = 1
    end
  end

  updateEnabled(steps)
  return newOn
end

function animator.moveSequencers(axis, delta, wrap)
  local newOn = {}
  for i=1,#animator.sequencers do
    local resp = moveSteps(animator.sequencers[i].steps, axis, delta, wrap)
    animator.sequencers[i]:regenStepMap()
    for pos,n in pairs(resp) do newOn[pos] = n end
  end
  animator.setOnToNew(newOn)
end

function animator.moveSequencersPos(axis, val, wrap)
  local newOn = {}
  for i=1,#animator.sequencers do
    local resp = moveStepsPos(i, axis, val, wrap)
    animator.sequencers[i]:regenStepMap()
    for pos,n in pairs(resp) do newOn[pos] = n end
  end
  animator.setOnToNew(newOn)
end

function animator.setOnToNew(newOn)
  for pos,_ in pairs(animator.on) do
    if newOn[pos] ~= nil then
      animator.on[pos] = animator.enabled[pos]
    else
      animator.on[pos] = 0
    end
  end
end

function animator.handleSelectSnapshot(e)
  if animator.snapshots[e.i] == nil or e.isClearHeld then
    animator.snapshots[e.i] = Snapshot.new(animator)
  end

  setToSnapshot(animator.snapshots[e.i])
  animator.grid.snapshot = e.i
  animator.redraw()
end

function setToSnapshot(snapshot)
  animator.on = copyTable(snapshot.on)
  animator.enabled = copyTable(snapshot.enabled)
  animator.sequencers = deepcopy(snapshot.sequencers)

  for i=1,MAX_SEQ_NUM do
    params:set('seq' .. i .. 'intersect', snapshot.intersects[i])
    params:set('seq' .. i .. 'div', snapshot.divs[i])
  end
end

function animator.clearSeq(index)
  clearStepState(animator.sequencers[index].steps)
  clearOnState(animator.sequencers[index].steps)
  table.remove(animator.sequencers, index)
  animator.redraw()
end

function resetSeqParams(index)
  params:set('seq' .. index .. 'div', 1)
  params:set('seq' .. index .. 'intersect', 1)
end

function animator.clear(view)
  if view == 1 then
    animator.sequencers = {}
    animator.snapshots = {}
    animator.original = {}
    animator.on = initStepState()
    animator.enabled = initStepState()
  else
    animator.clearSeq(animator.grid.selected)
  end
end

function animator.reset(view)
  if view == 1 then
    for i=1,#animator.sequencers do
      animator.sequencers[i].divCount = 1
      animator.sequencers[i].index = 1
    end
  else
    animator.sequencers[animator.grid.selected].reset = true
  end
end

function animator.resetStepLevels()
  animator.stepLevels = getStepLevels()
end

function animator.setStepLevels(seq)
  animator.stepLevels = seq and reduceStepLevels(seq) or {}
end

function animator.save(txt)
  if txt then
    local path = norns.state.data .. txt
    local doodle = {
      name = txt,
      on = animator.on,
      enabled = animator.enabled,
      sequencers = animator.sequencers,
      snapshots = animator.snapshots,
      selectedSnapshot = animator.grid.snapshot,
      showIntroText = animator.showIntroText
    }
    tab.save(doodle, path .. '.doodle')
    params:write(path .. '.pset')
    animator.name = doodle.name
  else
    print('save canceled')
  end
end

function animator.load(path)
  if string.find(path, 'doodle') ~= nil then
    local doodle = tab.load(path)
    if doodle ~= nil then
      params:read(norns.state.data .. doodle.name ..'.pset')

      animator.name = doodle.name
      animator.showIntroText = doodle.showIntroText
      animator.on = doodle.on
      animator.enabled = doodle.enabled

      animator.sequencers = {}
      for i=1,#doodle.sequencers do
        local seq = doodle.sequencers[i]
        animator.sequencers[i] = Sequencer.new(seq, i)
      end

      animator.snapshots = {}
      for i=1,#doodle.snapshots do
        local snap = doodle.snapshots[i]
        newSnap = copyTable(snap)

        for j=1,#snap.sequencers do
          local seq = snap.sequencers[j]
          newSnap.sequencers[j] = Sequencer.new(seq, j)
        end
        animator.snapshots[i] = newSnap
      end

      animator.grid.snapshot = doodle.selectedSnapshot
    else
      print('you have no doodles')
    end
  end
end

function reduceStepLevels(seq, levels)
  levels = levels or {}
  local steps = seq.steps
  local findPos = findPosition
  local max = math.max
  for i=1,#steps do
    local step = steps[i]
    local pos = findPos(step.x, step.y)
    -- step activated
    if animator.on[pos] > 0 then
      if i == seq.index then
        levels[pos] = GRID_LEVELS.HIGH
      else
        levels[pos] = levels[pos] == nil
                and GRID_LEVELS.MED
                or max(levels[pos], GRID_LEVELS.MED)
      end
      -- step highlighted but not activated
    elseif i == seq.index then
      levels[pos] = levels[pos] == nil
              and GRID_LEVELS.LOW_MED
              or max(levels[pos], GRID_LEVELS.LOW_MED)
      -- step not highlighted or activated
    else
      levels[pos] = levels[pos] == nil
              and GRID_LEVELS.DIM
              or max(levels[pos], GRID_LEVELS.DIM)
    end
  end

  return levels
end

function getStepLevels()
  local levels = {}
  for i=1,#animator.sequencers do
    reduceStepLevels(animator.sequencers[i], levels)
  end
  return levels
end

function clearStepState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    animator.enabled[pos] = animator.enabled[pos] - 1
  end
end

function clearOnState(steps)
  for i=1,#steps do
    local step = steps[i]
    local pos = findPosition(step.x, step.y)
    if animator.on[pos] > 0 then
      animator.on[pos] = animator.enabled[pos]
    end
  end
end

return animator
