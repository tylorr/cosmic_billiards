local class = require 'middleclass'
local events = require 'events'
local co = require 'co_bridge'
local Vector = require 'vector'

local CameraComponent = class('CameraComponent')

function CameraComponent:initialize(transformComponent)
  self.transformComponent = transformComponent
end

function CameraComponent:create(entity)
  self.camera = entity.id
  co.start(self.monitorDrag, self)
end

function CameraComponent:monitorDrag()
  local yield = coroutine.yield
  local transform = self.transformComponent
  
  local pressed = co.observe(events.input, 'mouse', 'pressed', 2)
  local updateUntilReleased = co.updateUntil(co.observe(events.input, 'mouse', 'released', 2))
  while true do
    local startMousePos = Vector(yield(pressed))
    local startPos = transform:vectorPos(self.camera)

    while yield(updateUntilReleased) do
      local pos = startPos - (Vector(love.mouse.getPosition()) - startMousePos)
      transform:setPosition(self.camera, pos:txy())
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
