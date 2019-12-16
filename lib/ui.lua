local helpers = include('lib/helpers')
local ui = {}

function ui.redraw(levels)
  screen.clear()
  redrawSteps(levels)
  screen.fill()
  screen.update()
end

function redrawSteps(levels)
  local findXY = helpers.findXY
  local level, rect, fill, stroke = screen.level, screen.rect, screen.fill, screen.stroke

  for pos,val in pairs(levels) do
    local step = findXY(pos)
    local padding = 4
    local marginLeft = 22
    local marginTop = 4
    level(val)
    rect(step.x+(padding*step.x) + marginLeft, step.y+(padding*step.y) + marginTop, 3, 3)
    fill()
    stroke()
  end
end

return ui
