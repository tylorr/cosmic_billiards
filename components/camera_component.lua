local class = require 'middleclass'
local events = require 'events'
local co = require 'co'
local Vector = require 'vector'

local CameraComponent = class('CameraComponent')

CameraComponent.static.dependencies = {
  'behaviourComponent',
  'transformComponent',
}

function CameraComponent:initialize(behaviourComponent, transformComponent)
  self.behaviourComponent = behaviourComponent
  self.transformComponent = transformComponent
end

function CameraComponent:create(entity)
  self.camera = entity.id
  co.start(self.monitorDrag, self)
end

function CameraComponent:monitorDrag()
  local yield = coroutine.yield
  local behaviour = self.behaviourComponent
  local transform = self.transformComponent

  for mx,my in yield, co.observe(events.input, 'mouse', 'pressed', 2) do
    local startMousePos = Vector(mx, my)
    local startPos = transform:vectorPos(self.camera)

    local updateUntilReleased = behaviour:updateUntil(co.observe(events.input, 'mouse', 'released', 2))
    while yield(updateUntilReleased) do
      local pos = startPos - (Vector(love.mouse.getPosition()) - startMousePos)
      transform:setPosition(self.camera, pos:pack())
    end
  end
end

function CameraComponent:set()
  love.graphics.push()

  local x, y = unpack(self.transformComponent:position(self.camera))
  love.graphics.translate(-x, -y)
end

function CameraComponent.unset()
  love.graphics.pop()
end

return CameraComponent
