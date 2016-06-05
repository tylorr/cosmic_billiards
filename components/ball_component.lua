local class = require 'middleclass'
local co = require 'co'
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
  local a,b
  while true do
    a, b = yield(co.observe(events.physics, 'collide', 'beginContact'))

    local aId = a:getUserData()
    local bId = b:getUserData()

    if (aId == ball and self.pocketComponent:is(bId)) then
      self:checkFallOrLeavePocket(a, b, ball, bId)
    elseif bId == ball and self.pocketComponent:is(aId) then
      self:checkFallOrLeavePocket(a, b, ball, aId)
    end
  end
end

function BallComponent:checkFallOrLeavePocket(a, b, ball, pocket)
  co.scope(co.create(self.checkFall, self, ball, pocket), function()
    yield(co.observe(events.physics, 'collide', 'endContact', a, b))
  end)
end

function BallComponent:checkFall(ball, pocket)
  local pocketFixture = self.colliderComponent:fixture(pocket)
  local ballBody = self.colliderComponent:body(ball)
  while true do
    local x, y = ballBody:getPosition()

    if pocketFixture:testPoint(x, y) then
      self.entityManager:destroy(ball)
      return
    end

    yield(co.update())
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
