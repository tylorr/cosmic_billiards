local class = require 'middleclass'

local PocketCompnent = class('PocketCompnent')

function PocketCompnent:initialize()
  self.pockets = {}
end

function PocketCompnent:create(entity)
  self.pockets[entity.id] = true
end

function PocketCompnent:has(id)
  return self.pockets[id]
end

return PocketCompnent
