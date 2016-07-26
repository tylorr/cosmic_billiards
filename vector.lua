local class = require 'middleclass'

local Vector = class('Vector')

function Vector:initialize(x, y)
  self.x = x or 0
  self.y = y or 0
end

function Vector.__add(v1, v2)
  return Vector(v1.x + v2.x, v1.y + v2.y)
end

function Vector.__sub(v1, v2)
  return Vector(v1.x - v2.x, v1.y - v2.y)
end

function Vector:__unm()
  return Vector(-self.x, -self.y)
end

function Vector.__mul(a, b)
  if type(a) == 'number' then
    return Vector(b.x * a, b.y * a)
  elseif type(b) == 'number' then
    return Vector(a.x * b, a.y * b)
  else
    return Vector(a.x * b.x, a.y * b.y)
  end
end

function Vector.__div(a, b)
  if type(a) == 'number' then
    return Vector(a/ b.x , a / b.y)
  elseif type(b) == 'number' then
    return Vector(a.x / b, a.y / b)
  else
    return Vector(a.x / b.x, a.y / b.y)
  end
end

function Vector.__eq(v1, v2)
  return v1.x == v2.x and v1.y == v2.y
end

function Vector:__tostring()
  return '(' .. self.x .. ', ' .. self.y .. ')'
end

function Vector:__len()
  return self:magnitude()
end

function Vector:pack()
  return {self.x, self.y}
end

function Vector:unpack()
  return self.x, self.y
end

function Vector:sqrMagnitude()
  return Vector.dot(self, self)
end

function Vector:magnitude()
  return math.sqrt(self:sqrMagnitude())
end

function Vector:normalized()
  return self / self:magnitude()
end

function Vector:rotated(phi)
  local c = math.cos(phi)
  local s = math.sin(phi)
  return Vector(
    c * self.x - s * self.y,
    s * self.x + c * self.y
  )
end

function Vector.static.dot(v1, v2)
  return v1.x * v2.x + v1.y * v2.y
end

-- function Vector.static.cross(v1, v2)
--   return Vector(
--     v1.y * v2.z - v1.z * v2.y,
--     v1.z * v2.x - v1.x * v2.z,
--     v1.x * v2.y - v1.y * v2.x
--   )
-- end

return Vector
