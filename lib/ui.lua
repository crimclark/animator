local helpers = include('lib/helpers')
local constants = include('lib/constants')
local ui = {}

function ui.redraw(levels, grid, showIntroText)
  screen.clear()

  if showIntroText then return drawIntroText() end

  redrawSteps(levels)
  screen.level(5)
  local leftMargin = 4
  local topInfoY = 5

  if grid.view == 2 then
    screen.move(3, topInfoY)
    screen.text('intersect:')
    screen.move(125, topInfoY)
    screen.text_right(constants.INTERSECT_OPS[params:get('seq' .. grid.selected .. 'intersect')])
  end

  local bottomOptsY = 60
  screen.move(leftMargin, bottomOptsY)
  screen.text('reset')
  screen.move(105, bottomOptsY)
  screen.text('clear')
  screen.update()
end

function drawIntroText()
    local x = 62
    local y = 23
    screen.font_size(8)
    screen.move(x, y)
    screen.text_center('Hold 2 pads')
    screen.move(x, y+10)
    screen.text_center('-- | /')
    screen.move(x, y+20)
    screen.text_center('to draw a sequence')
    screen.update()
end

function redrawSteps(levels)
  local findXY = helpers.findXY
  local level, rect, fill = screen.level, screen.rect, screen.fill
  local padding = 4
  local marginLeft = 23
  local marginTop = 6

  for pos,val in pairs(levels) do
    local step = findXY(pos)
    level(val)
    rect(step.x+(padding*step.x) + marginLeft, step.y+(padding*step.y) + marginTop, 3, 3)
    fill()
  end

end

return ui
