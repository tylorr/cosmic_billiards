local class = require 'middleclass'

local EntityManager = class('EntityManager')

function EntityManager:initialize()
  self.nextID = 1;
  self.entities = {}
end

function EntityManager:create()
  local id = self.nextID;
  self.nextID = self.nextID + 1
  local entity = {
    id = id,
    active = true,
    name = "Entity"
  }
  self.entities[id] = entity;
  return entity;
end

function EntityManager:destroy(id)
  if type(id) == 'number' then
    self.entities[id] = nil
  else
    self.entities[id.id] = nil
  end
end

function EntityManager:setName(id, name)
  if self.entitites[id] then
    self.entitites[id].name = name
  end
end

return EntityManager
