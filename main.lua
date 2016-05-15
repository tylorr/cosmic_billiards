local EntityManager = require 'entity_manager'
local TransformComponent = require 'components.transform_component'
local PhysicsBodyComponent = require 'components.physics_body_component'
local ColliderComponent = require 'components.collider_component'
local CircleComponent = require 'components.circle_component'
local PolygonComponent = require 'components.polygon_component'
local CueBallComponent = require 'components.cue_ball_component'
local flatten = require('functional').flatten

local beholder = require 'beholder'
-- local inspect = require 'inspect'

local entityManager,
      transformComponent,
      physicsBodyComponent,
      colliderComponent,
      circleComponent,
      polygonComponent,
      cueBallComponent,
      physicsWorld

local function createPocket(radius)
  local entity = entityManager:create()
  transformComponent:create(entity)
  physicsBodyComponent:create(entity, 'static')
  colliderComponent:createCircle(entity, radius)
  colliderComponent:fixture(entity.id):setSensor(true)
  circleComponent:create(entity, 'fill', {0, 0, 0}, radius)
  return entity
end

local function createPockets(radius)
  local windowWidth, windowHeight = love.graphics.getDimensions()
  local right = windowWidth - radius
  local bottom = windowHeight - radius
  local middle = (windowHeight / 2.0)
  local side = (radius * math.cos(math.pi / 4.0)) * 0.8
  local rigthSide = windowWidth - side

  local pocketCoordinates = {
    { radius, radius }, { right, radius },
    { side, middle }, { rigthSide, middle },
    { radius, bottom }, { right, bottom }
  }

  for _, coord in ipairs(pocketCoordinates) do
    local entity = createPocket(radius)
    transformComponent:setPosition(entity.id, coord)
  end
end

local function createCushion(length, depth, leftAngle, rightAngle)
  local entity = entityManager:create()
  transformComponent:create(entity)

  local points = {}
  local hl = length / 2.0

  points[#points + 1] = {-hl, 0}

  local leftOffset = depth / math.tan(leftAngle)
  points[#points + 1] = {leftOffset - hl, -depth}

  local rightOffset = depth / math.tan(rightAngle)
  points[#points + 1] = {hl - rightOffset, -depth}

  points[#points + 1] = {hl, 0}

  points = flatten(points, true)

  physicsBodyComponent:create(entity, 'static')
  colliderComponent:createPolygon(entity, unpack(points))

  local fixture = colliderComponent:fixture(entity.id)
  fixture:setRestitution(1)

  polygonComponent:create(entity, 'line', {1, 1, 1}, unpack(points))

  return entity
end

local function createCushions(pocketRadius)
  local windowWidth, windowHeight = love.graphics.getDimensions()

  local verticalLength = (windowHeight / 2.0) - (3 * pocketRadius)
  local horizontalLength = windowWidth - (4 * pocketRadius)
  local cushionDepth = pocketRadius * math.cos(math.pi / 4.0)

  local cornerAngle = math.pi * 0.19
  local sideAngle = math.pi * 0.35

  local cushParamList = {
    {pocketRadius, (windowHeight * 0.25) + (pocketRadius / 2), verticalLength, cornerAngle, sideAngle, math.pi / 2},
    {pocketRadius, (windowHeight * 0.75) - (pocketRadius / 2), verticalLength, sideAngle, cornerAngle, math.pi / 2},
    {windowWidth - pocketRadius, (windowHeight * 0.25) + (pocketRadius / 2), verticalLength, sideAngle, cornerAngle, -math.pi / 2},
    {windowWidth - pocketRadius, (windowHeight * 0.75) - (pocketRadius / 2), verticalLength, cornerAngle, sideAngle, -math.pi / 2},
    {windowWidth / 2, pocketRadius, horizontalLength, cornerAngle, cornerAngle, math.pi},
    {windowWidth / 2, windowHeight - pocketRadius, horizontalLength, cornerAngle, cornerAngle, 0},
  }

  for _,cushionParams in ipairs(cushParamList) do
    local x, y, length, leftAngle, rightAngle, rotation = unpack(cushionParams)
    local cushion = createCushion(length, cushionDepth, leftAngle, rightAngle)
    transformComponent:setPosition(cushion.id, {x, y})
    transformComponent:setRotation(cushion.id, rotation)
  end
end

function love.load()
  love.graphics.setBackgroundColor(0, 150, 0)
  physicsWorld = love.physics.newWorld(0, 0, false)

  entityManager = EntityManager()
  transformComponent = TransformComponent()
  physicsBodyComponent = PhysicsBodyComponent(physicsWorld, transformComponent)
  colliderComponent = ColliderComponent(physicsBodyComponent)
  circleComponent = CircleComponent(transformComponent)
  polygonComponent = PolygonComponent(transformComponent)
  cueBallComponent = CueBallComponent(transformComponent, physicsBodyComponent)

  local pocketRadius = 16

  createPockets(pocketRadius)
  createCushions(pocketRadius)

  local width, height = love.graphics.getDimensions()
  local ball = entityManager:create()
  transformComponent:create(ball, {width / 2, height / 2})
  physicsBodyComponent:create(ball, 'dynamic')
  colliderComponent:createCircle(ball, 10)
  circleComponent:create(ball, 'fill', {255, 255, 255}, 10)
  cueBallComponent:create(ball)

  local body = physicsBodyComponent:body(ball.id)
  body:setLinearDamping(1.0)
  body:setAngularDamping(1.0)
  body:setBullet(true)
  -- body:applyLinearImpulse(-350, -270)

  local fixture = colliderComponent:fixture(ball.id)
  fixture:setRestitution(1)
end

function love.mousepressed(x, y, button)
  beholder.trigger('input', 'mouse', 'pressed', x, y, button)
end

function love.mousereleased(x, y, button)
  beholder.trigger('input', 'mouse', 'released', x, y, button)
end

function love.update(dt)
  physicsWorld:update(dt)
  physicsBodyComponent:updateTransforms()
end

function love.draw()
  circleComponent:draw()
  polygonComponent:draw()
end
