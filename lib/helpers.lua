local constants = include('animator/lib/constants')
local helpers = {}

function helpers.findPosition(x, y)
  return constants.GRID_LENGTH * (y - 1) + x
end

function helpers.findXY(pos)
  return {x = (pos - 1) % constants.GRID_LENGTH + 1, y = math.ceil(pos/constants.GRID_LENGTH)}
end

function helpers.copyTable(tbl)
  local copy = {}
  for k,v in pairs(tbl) do copy[k] = v end
  return copy
end

-- https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
local function helpers.deepcopy(o, seen)
  seen = seen or {}
  if o == nil then return nil end
  if seen[o] then return seen[o] end

  local no
  if type(o) == 'table' then
    no = {}
    seen[o] = no

    for k, v in next, o, nil do
      no[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    setmetatable(no, deepcopy(getmetatable(o), seen))
  else -- number, string, boolean, etc
    no = o
  end
  return no
end

return helpers
