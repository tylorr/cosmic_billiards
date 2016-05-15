local class = require 'middleclass'
local signal = require 'signal'
local Vector = require 'vector'

local TransformComponent = class('TransformComponent')

function TransformComponent:initialize()
  self.transforms = {}
  self.positionUpdated = signal()
  self.rotationUpdated = signal()
end

function TransformComponent:create(entity, position, rotation)
  self.transforms[entity.id] = {
    position = position or {0,0},
    rotation = rotation or 0
  }
end

function TransformComponent:destroy(entity)
  self.transforms[entity.id] = nil
end

function TransformComponent:position(id)
  return self.transforms[id] and self.transforms[id].position
end

function TransformComponent:vectorPos(id)
  return self.transforms[id] and Vector(unpack(self.transforms[id].position))
end

function TransformComponent:setPosition(id, position)
  local transform = self.transforms[id]
  if transform then
    transform.position = position
    self.positionUpdated(id, position)
  end
end

function TransformComponent:rotation(id)
  return self.transforms[id] and self.transforms[id].rotation
end

function TransformComponent:setRotation(id, rotation)
  local transform = self.transforms[id]
  if transform then
    transform.rotation = rotation
    self.rotationUpdated(id, rotation)
  end
end

return TransformComponent
