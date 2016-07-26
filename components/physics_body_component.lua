local class = require 'middleclass'
local events = require 'events'

local PhysicsBodyComponent = class('PhysicsBodyComponent')

PhysicsBodyComponent.static.dependencies = {
  'physicsWorld',
  'transformComponent'
}

function PhysicsBodyComponent:initialize(physicsWorld, transformComponent)
  self.physicsWorld = physicsWorld
  self.transformComponent = transformComponent
  self.bodies = {}

  transformComponent.positionUpdated:register(self, self.setPosition)
  transformComponent.rotationUpdated:register(self, self.setRotation)
end

function PhysicsBodyComponent:updateTransforms()
  for id,body in pairs(self.bodies) do
    local position = {body:getPosition()}
    self.transformComponent:setPosition(id, position)
    self.transformComponent:setRotation(id, body:getAngle())
  end
end

function PhysicsBodyComponent:create(entity, bodyType)
  local x,y = unpack(self.transformComponent:position(entity.id))
  local body = love.physics.newBody(self.physicsWorld, x, y, bodyType)
  self.bodies[entity.id] = body

  events.observeEntity('destroyed', entity.id, function()
    self.bodies[entity.id] = nil
  end)
end

function PhysicsBodyComponent:body(id)
  return self.bodies[id];
end

function PhysicsBodyComponent:setPosition(id, position)
  local body = self:body(id)
  if body then
    body:setPosition(unpack(position))
  end
end

function PhysicsBodyComponent:setRotation(id, rotation)
  local body = self:body(id)
  if body then
    body:setAngle(rotation)
  end
end

return PhysicsBodyComponent
