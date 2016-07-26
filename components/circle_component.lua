local class = require 'middleclass'
local events = require 'events'

local CircleComponent = class('CircleComponent')

CircleComponent.static.dependencies = {
  'transformComponent'
}

function CircleComponent:initialize(transformComponent)
  self.transformComponent = transformComponent
  self.circles = {}
end

function CircleComponent:create(entity, mode, color, radius)
  self.circles[entity.id] = {
    mode = mode,
    color = color,
    radius = radius
  }

  events.observeEntity('destroyed', entity.id, function()
    self.circles[entity.id] = nil
  end)
end

function CircleComponent:draw()
  for id,circle in pairs(self.circles) do
    love.graphics.setColor(circle.color)
    local x,y = unpack(self.transformComponent:position(id))
    love.graphics.circle(circle.mode, x, y, circle.radius, 2 * circle.radius)
  end
end

return CircleComponent
