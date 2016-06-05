local Observable = require 'observable'
local Signal = require 'signal'
local beholder = require 'beholder'

local co = {}

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

function co.all(...)
  return Observable.zip(...)
end

function co.any(...)
  return Observable.of(...):flatMap(
    function(x) return x end,
    function(x, ...) return x, ... end)
end

function co.replace(func, ...)
  local args = { n = select('#', ...); ... }
  return function()
    return func(unpack(args, 1, args.n))
  end
end

do
  local update = Signal()

  function co.update()
    return co.signal(update)
  end

  function co.triggerUpdate(dt)
    update(dt)
  end
end

function co.create(func, ...)
  local resume = coroutine.resume

  assert(type(func) == 'function', 'co.start first arg must be a function')

  local initialArgs = { n = select('#', ...); ... }
  local routine = coroutine.create(func)

  return Observable(function(observer)
    local subscription

    local function continue(...)
      -- TODO: consider pushing with observer:next(...)
      local ok,result = resume(routine, ...)
      if not ok then
        return observer:error('Failed to resume coroutine\n' .. tostring(result))
      end

      if observer.closed then return end

      if type(result) == 'table' and result.subscribe then
        -- TODO: consider pushing with observer:next(result)
        return result:subscribe({
          start = function(_, s)
            subscription = s
          end,
          next = function(_, ...)
            subscription:unsubscribe()
            if observer.closed then return end
            return continue(...)
          end
        })
      elseif type(result) == 'function' then
        -- Allow coroutine to return and exit any co.scope
        resume(routine)
        routine = coroutine.create(result)
        return continue()
      end

      return observer:complete()
    end

    continue(unpack(initialArgs, 1, initialArgs.n))

    return function()
      routine = nil
      if subscription then
        subscription:unsubscribe()
      end
    end
  end)
end

function co.start(func, ...)
  return co.create(func, ...):subscribe({})
end

function co.scope(subroutine, func)
  local subscription = subroutine:subscribe({})
  local status, err = pcall(func)
  subscription:unsubscribe()

  if not status then
    error(err)
  end
end

return co
