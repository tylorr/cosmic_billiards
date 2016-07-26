require 'coex'
local flatten = require('functional').flatten
local map = require('functional').map
local lowerFirst = require('string_util').lowercaseFirst
local events = require 'events'
local inspect = require 'inspect'

local packages = {
  'entity_manager',
  'components.behaviour_component',
  'components.transform_component',
  'components.physics_body_component',
  'components.collider_component',
  'components.circle_component',
  'components.polygon_component',
  'components.cue_ball_component',
  'components.pocket_component',
  'components.ball_component',
  'components.camera_component',
  'components.gravity_component',
}

local container = {}

local function randomColor()
  local r = love.math.random
  return { r(255), r(255), r(255) }
end

local function createPocket(radius)
  local entity = container.entityManager:create()
  container.transformComponent:create(entity)
  container.physicsBodyComponent:create(entity, 'static')
  container.colliderComponent:createCircle(entity, radius)
  container.colliderComponent:fixture(entity.id):setSensor(true)
  container.circleComponent:create(entity, 'fill', {0, 0, 0}, radius)
  container.pocketComponent:create(entity)
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
    container.transformComponent:setPosition(entity.id, coord)
  end
end

local function createCushion(length, depth, leftAngle, rightAngle)
  local entity = container.entityManager:create()
  container.transformComponent:create(entity)

  local points = {}
  local hl = length / 2.0

  points[#points + 1] = {-hl, 0}

  local leftOffset = depth / math.tan(leftAngle)
  points[#points + 1] = {leftOffset - hl, -depth}

  local rightOffset = depth / math.tan(rightAngle)
  points[#points + 1] = {hl - rightOffset, -depth}

  points[#points + 1] = {hl, 0}

  points = flatten(points, true)

  container.physicsBodyComponent:create(entity, 'static')
  container.colliderComponent:createPolygon(entity, unpack(points))

  local fixture = container.colliderComponent:fixture(entity.id)
  fixture:setRestitution(1)

  container.polygonComponent:create(entity, 'fill', {20, 100, 100}, unpack(points))

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
    container.transformComponent:setPosition(cushion.id, {x, y})
    container.transformComponent:setRotation(cushion.id, rotation)
  end
end

local function createBall(radius, color)
  local entity = container.entityManager:create()
  container.transformComponent:create(entity)
  container.physicsBodyComponent:create(entity, 'dynamic')
  container.colliderComponent:createCircle(entity, radius)
  container.circleComponent:create(entity, 'fill', color, radius)
  container.ballComponent:create(entity)
  container.gravityComponent:create(entity)

  local body = container.physicsBodyComponent:body(entity.id)
  body:setLinearDamping(1.0)
  body:setAngularDamping(1.0)
  body:setBullet(true)

  local fixture = container.colliderComponent:fixture(entity.id)
  fixture:setRestitution(1)

  return entity
end

local function createBalls()
  local ballRadius = 12

  local cue = createBall(ballRadius, {255, 255, 255})
  container.cueBallComponent:create(cue)
  container.transformComponent:setPosition(cue.id, {200, 200})

  local ball
  ball = createBall(ballRadius, randomColor())
  container.transformComponent:setPosition(ball.id, {200, 400})

  ball = createBall(ballRadius, randomColor())
  container.transformComponent:setPosition(ball.id, {300, 400})

  ball = createBall(ballRadius, randomColor())
  container.transformComponent:setPosition(ball.id, {200, 600})

  ball = createBall(ballRadius, randomColor())
  container.transformComponent:setPosition(ball.id, {200, 800})

  ball = createBall(ballRadius, randomColor())
  container.transformComponent:setPosition(ball.id, {300, 600})

  ball = createBall(ballRadius, randomColor())
  container.transformComponent:setPosition(ball.id, {300, 800})
end

local function createStar(radius, gravityRadius)
  local entity = container.entityManager:create()
  container.transformComponent:create(entity)
  container.physicsBodyComponent:create(entity, 'dynamic')
  container.circleComponent:create(entity, 'fill', { 200, 200, 0 }, radius)

  local fixture = container.colliderComponent:createCircle(entity, radius)
  fixture:setDensity(gravityRadius)
  fixture:setRestitution(1)

  local gravityFixture = container.colliderComponent:createCircle(entity, gravityRadius)
  gravityFixture:setSensor(true)
  gravityFixture:setDensity(10)

  local body = container.physicsBodyComponent:body(entity.id)
  body:setLinearDamping(1.0)
  body:setAngularDamping(1.0)
  -- body:setBullet(true)
  -- body:setMass(500)
  body:resetMassData()

  container.gravityComponent:create(entity, gravityFixture)

  print('star mass: ', body:getMass())

  return entity
end

local function buildContainer()
  for _,package in ipairs(packages) do
    local klass = require(package)
    local name = lowerFirst(klass.name)

    local deps = klass.dependencies or {}
    local instance = klass(unpack(map(deps, function(d) return container[d] end)))

    container[name] = instance
  end
end

function love.load()
  container.physicsWorld = love.physics.newWorld(0, 0, false)
  buildContainer()

  love.graphics.setBackgroundColor(0, 150, 0)

  local pocketRadius = 30

  createPockets(pocketRadius)
  createCushions(pocketRadius)
  createBalls()

  local star = createStar(20, 200)
  container.transformComponent:setPosition(star.id, {250, 500})

  local camera = container.entityManager:create()
  container.transformComponent:create(camera)
  container.cameraComponent:create(camera)
end

function love.mousepressed(x, y, button)
  events.triggerInput('mouse', 'pressed', button, x, y)
end

function love.mousereleased(x, y, button)
  events.triggerInput('mouse', 'released', button, x, y)
end

function love.update(dt)
  container.physicsWorld:update(dt)
  container.behaviourComponent:update(dt)
  container.physicsBodyComponent:updateTransforms()
end

function love.draw()
  container.cameraComponent:set()

  container.circleComponent:draw()
  container.polygonComponent:draw()
  container.colliderComponent:debugDraw()

  container.cameraComponent:unset()
end
