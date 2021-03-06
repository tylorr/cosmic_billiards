local class = require 'middleclass'
local co = require 'co'
local events = require 'events'

local yield = coroutine.yield

local BallComponent = class('BallComponent')

BallComponent.static.dependencies = {
  'entityManager',
  'behaviourComponent',
  'pocketComponent',
  'colliderComponent',
}

function BallComponent:initialize(entityManager, behaviourComponent, pocketComponent, colliderComponent)
  self.entityManager = entityManager
  self.behaviourComponent = behaviourComponent
  self.pocketComponent = pocketComponent
  self.colliderComponent = colliderComponent
  self.balls = {}
end

function BallComponent:monitorPocket(ball)
  local fixture = self.colliderComponent:fixture(ball)
  assert(fixture, 'ball component missing collider: ' .. ball)

  local pocketCollision =
    co.observe(events.physics, 'collide', 'beginContact', fixture)
      :filter(function(otherFixture)
        local otherId = otherFixture:getUserData()
        return self.pocketComponent:has(otherId)
      end)

  for pocketFixture in yield, pocketCollision do
    local checkFall = co.create(self.checkFall, self, ball, pocketFixture)
    local endContact = co.observe(events.physics, 'collide', 'endContact', fixture, pocketFixture)
    yield(checkFall:takeUntil(endContact))
  end
end

function BallComponent:checkFall(ball, pocketFixture)
  local behaviour = self.behaviourComponent
  local ballBody = self.colliderComponent:body(ball)
  while yield(behaviour:waitForUpdate()) do
    if pocketFixture:testPoint(ballBody:getPosition()) then
      return self.entityManager:destroy(ball)
    end
  end
end

function BallComponent:create(entity)
  self.balls[entity.id] = self.behaviourComponent:start(entity.id, self.monitorPocket, self)
end

return BallComponent
