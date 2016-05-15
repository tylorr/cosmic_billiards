local class = require 'middleclass'

local ColliderComponent = class('ColliderComponent')

function ColliderComponent:initialize(physicsBodyComponent)
  self.physicsBodyComponent = physicsBodyComponent
  self.fixtures = {}
end

local function createFixture(self, entity, shape)
  local body = self.physicsBodyComponent:body(entity.id)
  assert(body, 'Collider must already have a physics body')

  local fixture = love.physics.newFixture(body, shape)
  fixture:setUserData(entity.name .. ':collider')

  self.fixtures[entity.id] = fixture
end

function ColliderComponent:createCircle(entity, radius)
  local shape = love.physics.newCircleShape(radius)
  createFixture(self, entity, shape)
end

function ColliderComponent:createPolygon(entity, ...)
  local shape = love.physics.newPolygonShape(...)
  createFixture(self, entity, shape)
end

function ColliderComponent:shape(id)
  return self.fixtures[id] and self.fixtures[id]:getShape()
end

function ColliderComponent:body(id)
  return self.fixtures[id] and self.fixtures[id]:getBody()
end

function ColliderComponent:fixture(id)
  return self.fixtures[id]
end

return ColliderComponent
