local co = require 'co'
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
    signal:register(observer, observer.next)
    return function() 
      signal:deregister(observer) 
    end
  end)
end

return co
