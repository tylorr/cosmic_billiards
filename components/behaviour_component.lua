local class = require 'middleclass'
local co = require 'co'
local events = require 'events'
local Signal = require 'signal'

local BehaviourComponent = class('BehaviourComponent')

function BehaviourComponent:initialize()
  self.co = co
  self.updateSignal = Signal()
  self.updateObservable = co.signal(self.updateSignal)
end

function BehaviourComponent:update(dt)
  self.updateSignal(dt)
end

function BehaviourComponent:waitForUpdate()
  return self.updateObservable
end

function BehaviourComponent:updateUntil(other)
  return self.updateObservable:takeUntil(other)
end

-- luacheck: no self
function BehaviourComponent:start(entityId, func, target, ...)
  return co.create(func, target, entityId, ...)
    :takeUntil(co.observe(events.entity, 'destroyed', entityId))
    :subscribe({})
end

return BehaviourComponent
