local helpers = include('lib/helpers')
local ui = {}

function ui.redraw(levels)
  screen.clear()
  screen.aa(1)
  redrawSteps(levels)
  screen.fill()
  screen.update()
end

function redrawSteps(levels)
  local findXY = helpers.findXY
  local level, rect, fill, stroke, update = screen.level, screen.rect, screen.fill, screen.stroke, screen.update

  for pos,val in pairs(levels) do
    local step = findXY(pos)
    local padding = 4
    level(val)
    rect(step.x+(padding*step.x) - padding, step.y+(padding*step.y) - padding, 3, 3)
    fill()
    stroke()
    update()
  end
end

return ui
