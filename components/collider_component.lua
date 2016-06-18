local class = require 'middleclass'
local events = require('events')
local triggerPhysics = require('events').triggerPhysics

local ColliderComponent = class('ColliderComponent')

local function beginContact(a, b, contact)
  triggerPhysics('collide', 'beginContact', a, b, contact)
  triggerPhysics('collide', 'beginContact', b, a, contact)
end

local function endContact(a, b, contact)
  triggerPhysics('collide', 'endContact', a, b, contact)
  triggerPhysics('collide', 'endContact', b, a, contact)
end

local function preSolve(a, b, contact)
  triggerPhysics('collide', 'preSolve', a, b, contact)
  triggerPhysics('collide', 'preSolve', b, a, contact)
end

local function postSolve(a, b, contact, normalimpulse, tangentimpulse)
  triggerPhysics('collide', 'postSolve', a, b, contact, normalimpulse, tangentimpulse)
  triggerPhysics('collide', 'postSolve', b, a, contact, normalimpulse, tangentimpulse)
end

function ColliderComponent:initialize(world, physicsBodyComponent)
  self.world = world
  self.physicsBodyComponent = physicsBodyComponent
  self.fixtures = {}

  world:setCallbacks(beginContact, endContact, preSolve, postSolve)
end

local function createFixture(self, entity, shape)
  local body = self.physicsBodyComponent:body(entity.id)
  assert(body, 'Collider must already have a physics body')

  local fixture = love.physics.newFixture(body, shape)
  fixture:setUserData(entity.id)

  local fixtures = self.fixtures[entity.id] or {}
  fixtures[#fixtures + 1] = fixture
  self.fixtures[entity.id] = fixtures

  events.observeEntity('destroyed', entity.id, function()
    self.fixtures[entity.id] = nil
  end)
end

function ColliderComponent:createCircle(entity, radius)
  local shape = love.physics.newCircleShape(radius)
  createFixture(self, entity, shape)
end

function ColliderComponent:createPolygon(entity, ...)
  local shape = love.physics.newPolygonShape(...)
  createFixture(self, entity, shape)
end

function ColliderComponent:shape(id)
  return self.fixtures[id] and self.fixtures[id][1]:getShape()
end

function ColliderComponent:body(id)
  return self.fixtures[id] and self.fixtures[id][1]:getBody()
end

function ColliderComponent:fixture(id)
  return self.fixtures[id] and self.fixtures[id][1]
end

function ColliderComponent:fixtures(id)
  return self.fixtures[id]
end

return ColliderComponent
