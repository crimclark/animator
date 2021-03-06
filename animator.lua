-- Animator
--
-- -- | /
--
-- 2D Polyphonic Sequencer
-- .....................................................
--
-- v1.??? by @crim
--
-- Hold 2 pads to draw a
-- horizontal, vertical or
-- diagonal sequence
--
-- Toggle the options page with
-- the bottom right grid pad
-- to change clock divisions
-- and intersect behavior for
-- each sequence.
--
-- E2 / E3 : move sequencers
-- K2 / K3 : reset / clear

local constants = include('lib/constants')
local parameters = include('lib/parameters')
local animator = include('lib/animator')
local ui = include('lib/ui')
local GRID = include('lib/Grid')
local g = grid.connect()
engine.name = 'MollyThePoly'

function pulse()
  while true do
    clock.sync(1/4)
    animator.count()
  end
end

function init()
  crow.ii.pullup(true)
  crow.ii.jf.mode(1)
  math.randomseed(os.time())
  parameters.init(animator)
  animator.grid = GRID.new(animator)
  animator.midiDevice = midi.connect(1)
  g.key = animator.grid:createKeyHandler()
  animator.noteOffMetro.event = animator.allNotesOff
  clock.run(pulse)
  clock.run(function() animator.grid.patternManager:pulse() end)
  animator.redraw()
end

function animator.redraw()
  if animator.grid.view == 1 then
    animator.resetStepLevels()
    animator.grid:redraw()
    redraw()
  else
    animator.setStepLevels(animator.sequencers[animator.grid.selected])
    animator.grid:redraw()
    redraw()
  end
end

function redraw()
  ui.redraw(animator.stepLevels, animator.grid, animator.showIntroText)
end

function key(n, z)
  if z == 1 then
    if n == 2 then
      animator.reset(animator.grid.view)
      animator.redraw()
    elseif n == 3 then
      animator.clear(animator.grid.view)
      animator.redraw()
    end
  end
end

function enc(n, delta)
  if n == 2 then
    animator.moveSequencers('y', delta, constants.CANVAS_HEIGHT)
    animator.redraw()
  elseif n == 3 then
    animator.moveSequencers('x', delta, constants.CANVAS_LENGTH)
    animator.redraw()
  end
end
