local constants = include('animator/lib/constants')
local EVENT_PATTERN = constants.EVENT_PATTERN
local pattern_time = require 'pattern_time'
local PATTERN_NUM = 4

local PatternManager = {}
PatternManager.__index = PatternManager

function PatternManager.new(options)
  local controller = {
    quantizeEvents = {},
    patterns = {},
    callbacks = options.callbacks
  }
  setmetatable(controller, PatternManager)
  setmetatable(controller, {__index = PatternManager})

  for i=1,PATTERN_NUM do
    controller.patterns[i] = pattern_time.new()
    controller.patterns[i].process = function(e)
      controller:eventExec(e)
    end
  end

  return controller
end

function PatternManager:event(e)
  if params:get('quantize') == 2 then
    self:queueEvent(e)
  else
    if e.type ~= EVENT_PATTERN then self:eventRecord(e) end
    self:eventExec(e)
  end
end

function PatternManager:processQuantizeEvents()
  local numEvents = #self.quantizeEvents
  if numEvents > 0 then
    for i=1,numEvents do
      local e = self.quantizeEvents[i]
      if e.type ~= EVENT_PATTERN then self:eventRecord(e) end
      self:eventExec(e)
    end
    self.quantizeEvents = {}
  end
end

function PatternManager:eventExec(e)
  if e.type == EVENT_PATTERN then
    self:patternSelect(e.i, e.isClearHeld)
  end

  self.callbacks[e.type](e)
end

function PatternManager:eventRecord(e)
  for i=1,PATTERN_NUM do
    self.patterns[i]:watch(e)
  end
end

function PatternManager:queueEvent(e)
   self.quantizeEvents[#self.quantizeEvents+1] = e
end

function PatternManager:patternSelect(i, isClearHeld)
  local pattern = self.patterns[i]
  if pattern.rec == 1 then
    pattern:rec_stop()
    pattern:stop()
    if isClearHeld then pattern:clear() else pattern:start() end
  elseif pattern.count == 0 then
    stopOtherPattern(self.patterns)
    pattern:rec_start()
  elseif pattern.play == 1 then
    if isClearHeld then
      pattern:clear()
      pattern:rec_start()
    else
      pattern:stop()
    end
  else
    stopOtherPattern(self.patterns)
    if isClearHeld then
      pattern:clear()
      pattern:rec_start()
    else
      pattern:start()
    end
  end
end

function PatternManager:pulse()
  while true do
    clock.sync(1/4 * params:get('quant_div'))
    self:processQuantizeEvents()
  end
end

function stopOtherPattern(patterns)
  for i=1,PATTERN_NUM do
    local otherPat = patterns[i]
    if otherPat.rec == 1 or otherPat.play == 1 then
      otherPat:rec_stop()
      otherPat:stop()
    end
  end
end

return PatternManager
