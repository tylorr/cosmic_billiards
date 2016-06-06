local every = require('functional').every
local map = require('functional').map
local filter = require('functional').filter

local Observable = require 'observable'

function Observable:map(func)
  assert(type(func) == 'function', tostring(func) .. ' is not a function')

  return Observable.new(function(observer)
    self:subscribe({
      next = function(_, ...)
        if observer.closed then return end

        local function checkStatus(status, ...)
          if not status then
            return observer:error((...))
          end
          return observer:next(...)
        end

        return checkStatus(pcall(function(...)
          return func(...)
        end, ...))
      end,
      error = function(_, err) return observer:error(err) end,
      complete = function(_, ...) return observer:complete(...) end
    })
  end)
end

function Observable:flatMap(selector, resultSelector)
  assert(type(selector) == 'function', tostring(selector) .. 'is not a function')

  if resultSelector then
    assert(type(resultSelector) == 'function', tostring(resultSelector) .. 'is not a function')
  end

  return Observable.new(function(observer)
    local completed = false
    local subscriptions = {}

    local function closeIfDone()
      if completed and #subscriptions <= 0 then
        observer:complete()
      end
    end

    local outerSubscription = self:subscribe({
      next = function(_, outerValue, ...)
        local function observeInner(...)
          Observable.from(...):subscribe({
            start = function(innerObserver, s)
              innerObserver._subscription = s
              subscriptions[#subscriptions + 1] = s
            end,

            next = function(_, ...)
              if resultSelector then
                local function checkStatus(status, ...)
                  if not status then
                    return observer:error((...))
                  end
                  observer:next(...)
                end

                checkStatus(pcall(function(...)
                  return resultSelector(outerValue, ...)
                end, ...))
              else
                observer:next(...)
              end
            end,

            error = function(_, err) observer:error(err) end,

            complete = function(innerObserver)
              subscriptions = filter(subscriptions, function(x) return x ~= innerObserver._subscription end)
              closeIfDone()
            end
          })
        end

        local function checkStatus(status, ...)
          if not status then
            return observer:error((...))
          end
          observeInner(...)
        end

        checkStatus(pcall(function(...)
          return selector(...)
        end, outerValue, ...))
      end,

      error = function(_, err) return observer:error(err) end,

      complete = function()
        completed = true
        closeIfDone()
      end
    })

    return function()
      for _, subscription in ipairs(subscriptions) do
        subscription:unsubscribe()
        outerSubscription:unsubscribe()
      end
    end
  end)
end

function Observable:switch()
  return Observable.new(function(observer)
    local innerSubscription
    local latest = 0
    local hasLatest = false
    local stopped = false
    local outerSubscription = self:subscribe({
      next = function(_, innerSource)
        -- print('innerSource', inspect(innerSource))
        latest = latest + 1
        local id = latest
        hasLatest = true

        if innerSubscription then
          innerSubscription:unsubscribe()
        end

        innerSubscription = innerSource:subscribe({
          next = function(_, ...)
            if latest == id then
              observer:next(...)
            end
          end,
          error = function(_, err)
            if latest == id then
              observer:error(err)
            end
          end,
          complete = function()
            if latest == id then
              hasLatest = false
              if stopped then
                observer:complete()
              end
            end
          end
        })
      end,

      error = function(_, err)
        observer:error(err)
      end,

      complete = function()
        stopped = true
        if not hasLatest then
          observer:complete()
        end
      end
    })

    return function()
      outerSubscription:unsubscribe()
      if innerSubscription then
        innerSubscription:unsubscribe()
      end
    end
  end)
end

-- static api

local ZipObserver = {}
local ZipObserverMt = { __index = ZipObserver }

local function notEmpty(x) return #x > 0 end
local function popFirst(x) return table.remove(x, 1) end
local function identity(x) return x end
local function notTheSame(i)
  return function(_, j)
    return j ~= i
  end
end

function ZipObserver.new(observer, i, selector, queue, done)
  return setmetatable({
    _observer = observer,
    _i = i,
    _selector = selector,
    _queue = queue,
    _done = done
  }, ZipObserverMt)
end

function ZipObserver:next(x)
  do
    local q = self._queue[self._i]
    q[#q + 1] = x
  end
  if every(self._queue, notEmpty) then
    local function checkStatus(status, ...)
      if not status then
        return self._observer:error((...))
      end
      return self._observer:next(...)
    end

    local values = map(self._queue, popFirst)
    checkStatus(pcall(function(...)
      return self._selector(...)
    end, unpack(values)))

  elseif every(filter(self._done, notTheSame(self._i)), identity) then
    self._observer:complete()
  end
end

function ZipObserver:error(err)
  self._observer:error(err)
end

function ZipObserver:complete()
  self._done[self._i] = true
  if every(self._done, identity) then
    self._observer:complete()
  end
end

function Observable.zip(...)
  local observables = {...}
  local selector

  if type(observables[#observables]) == 'function' then
    selector = observables[#observables]
    observables[#observables] = nil
  else
    selector = function(...) return {...} end
  end

  -- Allow passing array of observables
  if observables[1] and observables[1][1] then
    observables = observables[1]
  end

  assert(#observables > 0, 'Too few observables passed to zip')

  return Observable.new(function(observer)
    local queue = {}
    local done = {}
    for i=1, #observables do
      queue[i] = {}
      done[i] = false
    end

    local subscriptions = {}
    for i=1, #observables do
      subscriptions[i] = observables[i]:subscribe(
        ZipObserver.new(observer, i, selector, queue, done))
    end

    return function()
      for _,subscription in ipairs(subscriptions) do
        subscription:unsubscribe()
      end
    end
  end)
end

function Observable.merge(...)
  local observables = {...}

  -- Allow passing array of observables
  if observables[1] and observables[1][1] then
    observables = observables[1]
  end

  assert(#observables > 0, 'Too few observables passed to merge')

  return Observable.new(function(observer)
    local done = {}
    for i=1, #observables do
      done[i] = false
    end

    local subscriptions = {}
    for i=1, #observables do
      subscriptions[i] = observables[i]:subscribe({
        next = function(_, ...)
          observer:next(...)
        end,
        error = function(_, err)
          observer:error(err)
        end,
        complete = function()
          done[i] = true
          if every(done, identity) then
            observer:complete()
          end
        end
      })
    end

    return function()
      for _,subscription in ipairs(subscriptions) do
        subscription:unsubscribe()
      end
    end
  end)
end

return Observable
