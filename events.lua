local beholder = require 'beholder'
local uppercaseFirst = require('string_util').uppercaseFirst
local bind = require('functional').bind

local events = {
  physics = {},
  input = {},
  entity = {},
}

for name,handle in pairs(events) do
  local upperName = uppercaseFirst(name)
  events['trigger' .. upperName] = bind(beholder.trigger, handle)
  events['observe' .. upperName] = bind(beholder.observe, handle)
end

return setmetatable(events, { __index = beholder })
