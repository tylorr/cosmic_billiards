local Signal = require 'signal'
local class = require 'middleclass'
local events = require 'events'
local append = require('list').append
local pack = require('util').pack
local unpackn = require('util').unpack

local cocreate = coroutine.create
local resume = coroutine.resume

local co = {}

local ObservingSignal = class('ObservingSignal', Signal)

function ObservingSignal:initialize(...)
  self.args = pack(...)
end

function ObservingSignal:register(observer, method)
  self.id = events.observe(unpackn(self.args))
  Signal.register(self, observer, method)
end

function ObservingSignal:deregister(observer, method)
  if self.id then
    events.stopObserving(self.id)
    self.id = nil
  end
  Signal.deregister(self, observer, method)
end

function co.observe(...)
  local observingSignal

  local handler = function(...)
    events.stopObserving(observingSignal.id)
    return observingSignal(...)
  end

  observingSignal = ObservingSignal(append(handler, ...))
  return observingSignal
end

local SignalGroup = class('SignalGroup', Signal)

function SignalGroup:initialize(handlerFactory, ...)
  self.handlerFactory = handlerFactory
  self.signals = pack(...)
end

function SignalGroup:register(observer, method)
  -- print('register group', self)
  for i = 1, self.signals.n do
    self.signals[i]:register(self, self.handlerFactory(i))
  end
  Signal.register(self, observer, method)
end

function SignalGroup:deregisterChildren()
  for i = 1, self.signals.n do
    self.signals[i]:deregister(self)
  end
end

function SignalGroup:deregister(observer, method)
  self:deregisterChildren()
  Signal.deregister(self, observer, method)
end


function co.all(...)
  local pending
  local results = {}

  local signalGroup = SignalGroup(function(i)
    return function(group, ...)
      results[i] = {...}
      pending = pending - 1

      group.signals[i]:deregister(group)
      if pending == 0 then
        group(results)
      end
    end
  end, ...)

  pending = signalGroup.signals.n

  return signalGroup
end

function co.any(...)
  local signalGroup = SignalGroup(function(i)
    return function(group, ...)
      group:deregisterChildren()
      group(group.signals[i], ...)
    end
  end, ...)
  return signalGroup
end

function co.replace(func, ...)
  local arg = pack(...)
  return function()
    return func(unpackn(arg))
  end
end

do
  local update = Signal()

  function co.update()
    return update
  end

  function co.triggerUpdate(dt)
    update(dt)
  end
end

do
  local routines = {}

  function co.start(func, ...)
    assert(type(func) == 'function', 'co.start first arg must be a function')

    local id = {}
    routines[id] = cocreate(func)

    local function continue(...)
      if not routines[id] then
        return
      end

      local ok,result = resume(routines[id], ...)
      assert(ok, 'Failed to resume coroutine')

      if type(result) == 'table' and result.register then
        local s = result
        return s:register(id, function(_, ...)
          s:deregister(id)
          return continue(...)
        end)
      elseif type(result) == 'function' then
        routines[id] = cocreate(result)
        return continue()
      end

      routines[id] = nil
    end

    continue(...)

    return id
  end

  function co.stop(id)
    routines[id] = nil
  end
end

return co
