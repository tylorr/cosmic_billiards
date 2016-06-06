local co = require 'co'
local Signal = require 'signal'
local beholder = require 'beholder'
local Observable = require 'observable'

function co.observe(...)
  local args = {...}
  local handlerIndex = #args + 1
  return Observable(function(observer)
    args[handlerIndex] = function(...)
      return observer:next(...)
    end

    local id = beholder.observe(unpack(args))
    return function()
      beholder.stopObserving(id)
    end
  end)
end

function co.signal(signal)
  return Observable(function(observer)
    signal:register(observer, function(...)
      observer:next(...)
    end)

    return function() signal:deregister(observer) end
  end)
end

local update = Signal()

function co.update()
  return co.signal(update)
end

function co.triggerUpdate(dt)
  update(dt)
end

return co
