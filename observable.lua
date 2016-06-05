local every = require('functional').every
local map = require('functional').map
local filter = require('functional').filter

local Observable = {
  _VERSION = 'observable v1.0.0',
  _DESCRIPTION = [[
    Model for push based data sources
    Ported from https://github.com/zenparsing/zen-observable
  ]],
  _LICENSE = [[
    Port copyright (c) 2016 tylorr (Tylor Reynolds)
    Copyright (c) 2015 zenparsing (Kevin Smith)

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
    of the Software, and to permit persons to whom the Software is furnished to do
    so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]  
}

local function subscriptionClosed(subscription)
  return not subscription._observer
end

local function cleanupSubscription(subscription)
  local cleanup = subscription._cleanup
  if not cleanup then return end
  subscription._cleanup = nil
  cleanup()
end

local SubscriptionObserver = {}
local SubscriptionObserverMt = {}

function SubscriptionObserverMt:__index(key)
  if key == 'closed' then
    return subscriptionClosed(self._subscription)
  else
    return SubscriptionObserver[key]
  end
end

function SubscriptionObserver.new(subscription)
  return setmetatable({
    _subscription = subscription
  }, SubscriptionObserverMt)
end

function SubscriptionObserver:next(...)
  local subscription = self._subscription
  if subscriptionClosed(subscription) then return end

  local observer = subscription._observer

  local function checkStatus(status, ...)
    if not status then
      pcall(function() subscription.unsubscribe() end)
      error((...))
    end
    return ...
  end

  return checkStatus(pcall(function(...)
    return observer.next and observer:next(...)
  end, ...))
end

function SubscriptionObserver:error(value)
  local subscription = self._subscription
  if subscriptionClosed(subscription) then error(value) end

  local observer = subscription._observer
  subscription._observer = nil

  local function checkStatus(status, result)
    if not status then
      pcall(function() cleanupSubscription(subscription) end)
      error(result)
    end

    cleanupSubscription(subscription)
    return result
  end

  return checkStatus(pcall(function()
    return observer.error and observer:error(value) or error(value)
  end))
end

function SubscriptionObserver:complete(...)
  local subscription = self._subscription
  if subscriptionClosed(subscription) then return end

  local observer = subscription._observer
  subscription._observer = nil

  local function checkStatus(status, ...)
    if not status then
      pcall(function() cleanupSubscription(subscription) end)
      error((...))
    end

    cleanupSubscription(subscription)
    return ...
  end

  return checkStatus(pcall(function(...)
    return observer.complete and observer:complete(...)
  end, ...))
end

local Subscription = {}
local SubscriptionMt = {}

function SubscriptionMt:__index(key)
  if key == 'closed' then
    return subscriptionClosed(self)
  else
    return Subscription[key]
  end
end

local function cleanupFromSubscription(subscription)
  return function() subscription.unsubscribe() end
end

function Subscription.new(observer, subscriber)
  assert(type(observer) == 'table', 'Observer must be of type table')

  local self = setmetatable({
    _observer = observer
  }, SubscriptionMt)

  if observer.start then
    observer:start(self)
  end

  if subscriptionClosed(self) then return end

  observer = SubscriptionObserver.new(self)

  local status, err = pcall(function()
    local cleanup = subscriber(observer)

    if cleanup then
      if type(cleanup) == 'table' and type(cleanup.unsubscribe) == 'function' then
        cleanup = cleanupFromSubscription(cleanup)
      else
        assert(type(cleanup) == 'function', tostring(cleanup) .. ' is not a function')
      end

      self._cleanup = cleanup
    end
  end)

  if not status then
    return observer:error(err)
  end

  if subscriptionClosed(self) then
    cleanupSubscription(self)
  end

  return self
end

function Subscription:unsubscribe()
  if subscriptionClosed(self) then return end
  self._observer = nil
  cleanupSubscription(self)
end

local ObservableMt = {}

function ObservableMt:__index(key)
  if key == Observable then
    return function() return self end
  else
    return Observable[key]
  end
end

function Observable.new(subscriber)
  return setmetatable({ 
    _subscriber = subscriber 
  }, ObservableMt)
end

function Observable:subscribe(observer, ...)
  if (type(observer) == 'function') then
    observer = {
      next = observer,
      error = select(1, ...),
      complete = select(2, ...)
    }
  end
  return Subscription.new(observer, self._subscriber)
end

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

-- Public static api

function Observable.from(x, state, initial)
  local method = x[Observable]
  if method then
    local observable = method(x)

    assert(type(observable) == 'table', tostring(observable) .. ' is not a table')

    if observable.new == Observable.new then
      return observable
    end

    return Observable.new(function(observer) observable:subscribe(observer) end)
  end

  if type(x) == 'function' then
    local iterator = x
    return Observable.new(function(observer)
      local var = initial
      local function step(value, ...)
        var = value
        if var == nil then return false end

        observer:next(value, ...)
        return true
      end

      while true do
        if not step(iterator(state, var)) then break end
        if observer.closed then
          return
        end
      end

      observer:complete()
    end)
  end

  if type(x) == 'table' then
    local tbl = x
    return Observable.new(function(observer)
      for _,item in ipairs(tbl) do
        observer:next(item)

        if observer.closed then
          return
        end
      end

      observer:complete()
    end)
  end

  error(tostring(x) .. ' is not observable')
end

function Observable.of(...)
  local items = { n = select('#', ...); ... }
  return Observable.new(function(observer)
    for i=1,items.n do 
      observer:next(items[i])

      if observer.closed then
        return
      end
    end

    observer:complete()
  end)
end

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

setmetatable(Observable, {
  __call = function(_, ...) return Observable.new(...) end
})

return Observable
