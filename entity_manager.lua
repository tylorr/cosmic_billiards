local class = require 'middleclass'
local events = require 'events'

local EntityManager = class('EntityManager')

function EntityManager:initialize()
  self.nextID = 1;
  self.entities = {}
end

function EntityManager:create(name)
  local id = self.nextID;
  self.nextID = self.nextID + 1
  local entity = {
    id = id,
    name = name or "Entity"
  }
  self.entities[id] = entity;
  return entity;
end

function EntityManager:get(id)
  return self.entities[id]
end

function EntityManager:destroy(entity)
  local id
  if type(entity) == 'number' then
    id = entity
  else
    id = entity.id
  end
  self.entities[id] = nil
  events.triggerEntity('destroyed', id)
end

function EntityManager:setName(id, name)
  if self.entitites[id] then
    self.entitites[id].name = name
  end
end

return EntityManager
