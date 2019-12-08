local constants = require 'animator/lib/constants'
local helpers = require 'animator/lib/helpers'
local NAV_COL = constants.GRID_NAV_COL
local SNAPSHOT_NUM = 4
local selectedSnapshot = 1
local g = grid.connect()
local GRID_LEVELS = {DIM = 2, LOW_MED = 4, MED = 8, HIGH = 14 }

local GRID = {}
local state = {
  held = nil,
  selectedSnapshot = 0,
}

function GRID.draw(sequencers)
  g:all(0)
  local findXY = helpers.findXY
  for pos,level in pairs(getStepLevels(sequencers)) do
    local step = findXY(pos)
    g:led(step.x, step.y, level)
  end

  for i=1,SNAPSHOT_NUM do
    if selectedSnapshot == i then
      g:led(NAV_COL, i, GRID_LEVELS.HIGH)
    else
      g:led(NAV_COL, i, GRID_LEVELS.LOW_MED)
    end
  end
  g:refresh()
end

function GRID.key(x, y, z)
  if z == 1 then
    handleGridKeyDown(x, y)
  else
    state.held = nil
  end
end

function getStepLevels(sequencers)
  local levels = {}
  local findPos = helpers.findPosition
  local max = math.max
  for i=1,#sequencers do
    local seq = sequencers[i]
    local steps = seq.steps
    for i=1,#steps do
      local step = steps[i]
      local pos = findPos(step.x, step.y)
      -- step activated
      if on[pos] > 0 then
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
  end
  return levels
end

function gridKey(x, y, z)
  if z == 1 then
    handleGridKeyDown(x, y)
  else
    state.held = nil
  end
end

function handleGridKeyDown(x, y)
  if x <= LENGTH then
    mainSeqGridHandler(x, y)
  elseif x == NAV_COL then
    handleNavSelect(y)
  end
end

function handleNavSelect(y)
  if y >= 1 and y <= 4 then
    state.selectedSnapshot = y

    if snapshots[y] == nil then
      table.insert(snapshots, Snapshot.new{on = on, enabled = enabled, sequencers = sequencers})
    end

    on = copyTable(snapshots[y].on)
    enabled = copyTable(snapshots[y].enabled)
    sequencers = copyTable(snapshots[y].sequencers)
    gridDraw()
    redraw()
  end
end

function mainSeqGridHandler(x, y)
  if state.held ~= nil then
    for i=1,#sequencers do
      local ln = sequencers[i].length
      local steps = sequencers[i].steps
      if (state.held.x == steps[1].x and state.held.y == steps[1].y and x == steps[ln].x and y == steps[ln].y)
              or (state.held.x == steps[ln].x and state.held.y == steps[ln].y and x == steps[1].x and y == steps[1].y) then
        clearSeq(i)
        gridDraw()
        redraw()
        screen.clear()
        return
      end
    end

    local steps = getNewLineSteps(state.held, {x = x, y = y})
    if steps ~= nil then
      sequencers[#sequencers+1] = Sequencer.new{steps = steps}
      updateEnabled(steps)
      updateOnState(steps)
      state.held = {x = x, y = y}
    end
  else
    local pos = findPosition(x, y)
    if on[pos] > 0 then
      on[pos] = 0
    elseif enabled[pos] > 0 then
      -- set on to same number of enabled at position
      on[pos] = enabled[pos]
    end
    state.held = {x = x, y = y}
  end
  gridDraw()
  redraw()
  screen.clear()
end

function clearSeq(index)
  clearStepState(sequencers[index].steps)
  clearOnState(sequencers[index].steps)
  table.remove(sequencers, index)
end

return GRID
