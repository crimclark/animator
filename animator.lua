local constants = include('lib/constants')
local parameters = include('lib/parameters')
local animator = include('lib/animator')
local ui = include('lib/ui')
local GRID = include('lib/Grid')
local lfo = include('lib/lfo')
local g = grid.connect()
engine.name = 'MollyThePoly'

function init()
  math.randomseed(os.time())
  lfo.init(animator)
  parameters.init(animator)
  animator.grid = GRID.new(animator)
  g.key = animator.grid:createKeyHandler()
--  animator.clock.event = animator.count
  animator.clock.on_step = animator.count
  animator.clock:start()
  animator.redraw()
end

function animator.redraw()
  animator.resetStepLevels()
  animator.grid:redraw(animator.stepLevels)
  redraw()
end

function redraw()
  ui.redraw(animator.stepLevels)
end

function key(n, z) end

function enc(n, delta)
  if n == 2 then
    animator.moveSequencers('y', delta, constants.GRID_HEIGHT)
    animator.redraw()
  elseif n == 3 then
    animator.moveSequencers('x', delta, constants.GRID_LENGTH)
    animator.redraw()
  end
end
