local class = require 'middleclass'
local events = require 'events'
local co = require 'co_bridge'
local Vector = require 'vector'

local yield = coroutine.yield

local CameraComponent = class('CameraComponent')

function CameraComponent:initialize(transformComponent)
  self.transformComponent = transformComponent
end

function CameraComponent:create(entity)
  self.camera = entity.id
  co.start(self.monitorDrag, self)
end

local function switch(cases, casevar, ...)
  local func = cases[casevar] or cases.default
  if func then
    assert(type(func) == 'function', 'caseof only excepts table of functions')
    return func(casevar, ...)
  end
end

function CameraComponent:monitorDrag()
  local pressed = co.observe(events.input, 'mouse', 'pressed', 2)
  local updateUntilRelease = co.updateUntil(co.observe(events.input, 'mouse', 'released', 2))

  local transform = self.transformComponent
  local pos, diff
  local mousePos = Vector:allocate()
  while true do
    mousePos:initialize(yield(pressed))
    pos = transform:vectorPos(self.camera)
    diff = mousePos - pos

    while yield(updateUntilRelease) do
      mousePos:initialize(love.mouse.getPosition())
      pos = mousePos - diff
      transform:setPosition(self.camera, pos:txy())
    end
  end
end

function CameraComponent:set()
  love.graphics.push()

  local x, y = unpack(self.transformComponent:position(self.camera))
  love.graphics.translate(-x, -y)
end

function CameraComponent:unset()
  love.graphics.pop()
end

return CameraComponent
