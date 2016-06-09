local Observable = require 'observable'

local co = {}

function co.all(...)
  return Observable.zip(...)
end

function co.any(...)
  return Observable.of(...):flatMap(
    function(x) return x end,
    function(x, ...) return x, ... end)
end

function co.map(map)
  return Observable.from(pairs(map)):flatMap(
    function(x) return x end,
    function(x, ...)
      assert(type(map[x]) == 'function', 'co.map requires table of functions')
      return map[x](x, ...)
    end)
end

function co.replace(func, ...)
  local args = { n = select('#', ...); ... }
  return function()
    return func(unpack(args, 1, args.n))
  end
end

function co.create(func, ...)
  local resume = coroutine.resume
  local cocreate = coroutine.create

  assert(type(func) == 'function', 'co.start first arg must be a function')

  local initialArgs = { n = select('#', ...); ... }
  local routine = cocreate(func)

  return Observable(function(observer)
    local subscription

    local function step(...)
      if observer.closed then return end

      local ok,result = resume(routine, ...)
      if not ok then
        return observer:error('Failed to resume coroutine\n' .. tostring(result))
      end

      if observer.closed then return end

      if type(result) == 'table' and result.subscribe then
        observer:next('yield.observable', result)

        local function unsubscribeStep(_, ...)
          observer:next('yield.complete', ...)
          subscription:unsubscribe()
          return step(...)
        end

        return result:subscribe({
          start = function(_, s) subscription = s end,
          next = unsubscribeStep,
          error = function(_, err) return observer:error(err) end,
          complete = unsubscribeStep,
        })
      elseif type(result) == 'function' then
        observer:next('yield.function', result)

        -- Allow coroutine to return and exit any co.scope
        resume(routine)

        if observer.closed then return end

        routine = cocreate(result)
        return step()
      elseif result ~= nil then
        return observer:error('Yield on unrecognized value: ' .. tostring(result))
      end

      return observer:complete()
    end

    step(unpack(initialArgs, 1, initialArgs.n))

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
