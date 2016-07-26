local class = require 'middleclass'

local PolygonComponent = class('PolygonComponent')

PolygonComponent.static.dependencies = {
  'transformComponent'
}

function PolygonComponent:initialize(transformComponent)
  self.transformComponent = transformComponent
  self.polygons = {}
  self.dirtyPolygons = {}
end

function PolygonComponent:create(entity, mode, color, ...)
  self.polygons[entity.id] = {
    mode = mode,
    color = color,
    points = {...}
  }
end

function PolygonComponent:draw()
  for id,polygon in pairs(self.polygons) do
    love.graphics.push()
    love.graphics.translate(unpack(self.transformComponent:position(id)))
    love.graphics.rotate(self.transformComponent:rotation(id))

    love.graphics.setColor(polygon.color)
    love.graphics.polygon(polygon.mode, polygon.points)
    love.graphics.pop()
  end
end

return PolygonComponent
