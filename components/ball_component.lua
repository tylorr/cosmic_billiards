local class = require 'middleclass'
local co = require 'coex'
local events = require 'events'

local yield = coroutine.yield

local BallComponent = class('BallComponent')

function BallComponent:initialize(entityManager, pocketComponent, colliderComponent)
  self.entityManager = entityManager
  self.pocketComponent = pocketComponent
  self.colliderComponent = colliderComponent
  self.balls = {}
end

function BallComponent:monitorPocket(ball)
  local fixture = self.colliderComponent:fixture(ball)

  local pocketCollision = 
    co.observe(events.physics, 'collide', 'beginContact', fixture)
      :filter(function(otherFixture)
        local otherId = otherFixture:getUserData()
        return self.pocketComponent:has(otherId)
      end)

  for pocketFixture in yield, pocketCollision do
    co.scope(co.create(self.checkFall, self, ball, pocketFixture), function()
      yield(co.observe(events.physics, 'collide', 'endContact', fixture, pocketFixture))
    end)
  end
end

function BallComponent:checkFall(ball, pocketFixture)
  local ballBody = self.colliderComponent:body(ball)
  while yield(co.update()) do
    if pocketFixture:testPoint(ballBody:getPosition()) then
      return self.entityManager:destroy(ball)
    end
  end
end

function BallComponent:create(entity)
  local ball = {
    monitorRoutine = co.start(self.monitorPocket, self, entity.id)
  }

  events.observeEntity('destroyed', entity.id, function()
    ball.monitorRoutine:unsubscribe()
    self.balls[entity.id] = nil
  end)

  self.balls[entity.id] = ball
end

return BallComponent
