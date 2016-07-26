local class = require 'middleclass'
local events = require 'events'
local co = require 'co'

local yield = coroutine.yield

local GRAVITY = 500

local GravityComponent = class('GravityComponent')

GravityComponent.static.dependencies = {
  'behaviourComponent',
  'transformComponent',
  'colliderComponent',
}

function GravityComponent:initialize(behaviourComponent, transformComponent, colliderComponent)
  self.gravitors = {}
  self.behaviourComponent = behaviourComponent
  self.transformComponent = transformComponent
  self.colliderComponent = colliderComponent
end

local function applyGravity(self, id, fixture, otherFixture)
  local body = fixture:getBody()
  local otherId = otherFixture:getUserData()
  local otherBody = otherFixture:getBody()

  local behaviour = self.behaviourComponent
  while yield(behaviour:waitForUpdate()) do
    -- Consider simply getting position from body instead
    local position = self.transformComponent:vectorPos(id)
    local otherPosition = self.transformComponent:vectorPos(otherId)

    local selfToGravitor = otherPosition - position
    local squareDistance = selfToGravitor:sqrMagnitude()
    local combinedMass = body:getMass() * otherBody:getMass()
    local force = GRAVITY * (combinedMass / squareDistance)
    -- print(squareDistance, combinedMass, force)
    force = force * selfToGravitor:normalized()
    body:applyForce(force:unpack())
  end
end

local function monitorGravity(self, id)
  local fixture = self.colliderComponent:fixture(id)
  assert(fixture, 'gravity component missing collider: ' .. id)

  local gravityFieldCollision =
    co.observe(events.physics, 'collide', 'beginContact', fixture)
      :filter(function(otherFixture)
        local otherId = otherFixture:getUserData()
        return self:field(otherId)
      end)

  local behaviour = self.behaviourComponent
  for otherFixture in yield, gravityFieldCollision do
    behaviour:runUntil(id,
      co.create(applyGravity, self, id, fixture, otherFixture),
      co.observe(events.physics, 'collide', 'endContact', fixture, otherFixture))
  end
end

-- Field is optional, if present then will attract others with gravity component
function GravityComponent:create(entity, field)
  self.gravitors[entity.id] = {
    field = field,
    routine = self.behaviourComponent:start(entity.id, monitorGravity, self)
  }

  events.observeEntity('destroyed', entity.id, function()
    self.gravitors[entity.id] = nil
  end)
end

function GravityComponent:field(id)
  return self.gravitors[id] and self.gravitors[id].field
end

return GravityComponent
