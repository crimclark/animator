local helpers = include('lib/helpers')
local ui = {}

function ui.redraw(levels)
  screen.clear()
  redrawSteps(levels)
  local textY = 60
  screen.move(4, textY)
  screen.level(5)
  screen.text('reset')
  screen.move(105, textY)
  screen.text('clear')
  screen.update()
end

function redrawSteps(levels)
  local findXY = helpers.findXY
  local level, rect, fill = screen.level, screen.rect, screen.fill
  local padding = 4
  local marginLeft = 23
  local marginTop = 4

  for pos,val in pairs(levels) do
    local step = findXY(pos)
    level(val)
    rect(step.x+(padding*step.x) + marginLeft, step.y+(padding*step.y) + marginTop, 3, 3)
    fill()
  end
end

return ui
