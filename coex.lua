local co = require 'co'
local Signal = require 'signal'
local beholder = require 'beholder'
local Observable = require 'observable'
local iter = require 'iter'

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
    signal:register(observer, observer.next)
    return function() signal:deregister(observer, observer.next) end
  end)
end

local update = Signal()
local updateObservable = co.signal(update)

function co.triggerUpdate(dt)
  update(dt)
end

function co.update()
  return updateObservable
end

function co.updateUntil(other)
  return updateObservable:takeUntil(other)
end

function co.yieldUpdatesUntil(other)
  return iter.yield(updateObservable:takeUntil(other))
end

return co
