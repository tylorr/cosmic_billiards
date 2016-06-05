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

local ObservableMt = { __index = Observable }

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

-- Public static api

function Observable.from(x, state, initial)
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

setmetatable(Observable, {
  __call = function(_, ...) return Observable.new(...) end
})

return Observable
