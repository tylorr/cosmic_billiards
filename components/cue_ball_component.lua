local class = require 'middleclass'
local Vector = require 'vector'
local events = require 'events'
local bind = require('functional').bind

local CueBallComponent = class('CueBallComponent')

function CueBallComponent:initialize(transformComponent, physicsBodyComponent)
  self.transformComponent = transformComponent
  self.physicsBodyComponent = physicsBodyComponent

  events.observeInput('mouse', 'released', 1, bind(self.shootFrom, self))
end

function CueBallComponent:create(entity)
  self.cue = entity.id

  events.observeEntity('destroyed', entity.id, function()
    self.cue = nil
  end)
end

function CueBallComponent:shootFrom(x, y)
  if not self.cue then
    return
  end

  local mousePos = Vector(x, y)
  local cuePos = self.transformComponent:vectorPos(self.cue)
  local mouseToCue = cuePos - mousePos

  local body = self.physicsBodyComponent:body(self.cue)
  body:applyLinearImpulse(mouseToCue:unpack())
end

return CueBallComponent

