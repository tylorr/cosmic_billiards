local class = require 'middleclass'
local Vector = require 'vector'
local beholder = require 'beholder'
local bind = require('functional').bind

local CueBallComponent = class('CueBallComponent')

function CueBallComponent:initialize(transformComponent, physicsBodyComponent)
  self.transformComponent = transformComponent
  self.physicsBodyComponent = physicsBodyComponent

  beholder.observe('input', 'mouse', 'released', bind(self.shootFrom, self))
end

function CueBallComponent:create(entity)
  self.cue = entity
end

function CueBallComponent:shootFrom(x, y)
  local mousePos = Vector(x, y)
  local cuePos = self.transformComponent:vectorPos(self.cue.id)
  local mouseToCue = cuePos - mousePos

  local body = self.physicsBodyComponent:body(self.cue.id)
  body:applyLinearImpulse(mouseToCue:xy())
end

return CueBallComponent
