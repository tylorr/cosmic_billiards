local class = require 'middleclass'

local Signal = class('Signal')

function Signal:register(observer, method)
  table.insert(self, {
    o = observer,
    m = method
  })
end

function Signal:deregister(observer, method)
  for i = #self, 1, -1 do
    if (not observer or self[i].o == observer) and
       (not method   or self[i].m == method)
    then
      table.remove(self, i)
    end
  end
end

function Signal:notify(...)
  for i = 1, #self do
    self[i].m(self[i].o, ...)
  end
end

function Signal:__call(...)
  self:notify(...)
end

return Signal
