local deferred = require 'deferred'
local events = require 'events'

local cocreate = coroutine.create
local resume = coroutine.resume

local co = {}

function co.observe(...)
  local d = deferred.new()
  local id

  local handler = function(...)
    events.stopObserving(id)
    return d:resolve({...})
  end

  local arg = {...}
  arg[#arg + 1] = handler
  id = events.observe(unpack(arg))
  return d
end

function co.socket(signal)
  local d = deferred.new()
  signal:register(d, function(_, ...)
    d:resolve({...})
  end)
  return d
end

local function pack(v)
  return {v}
end

function co.all(...)
  return deferred.all({...})
end

function co.any(...)
  return deferred.first({...}):next(pack)
end

function co.replace(func, ...)
  local arg = {...}
  return function()
    return func(unpack(arg))
  end
end

local updates = {}

function co.update()
  local d = deferred.new()
  updates[#updates + 1] = d
  return d
end

local tremove = table.remove
function co.triggerUpdate(dt)
  local d
  for i = #updates, 1, -1 do
    d = updates[i]
    d:resolve({dt})
    tremove(updates, i)
  end
end

local routines = {}

function co.start(func, ...)
  assert(type(func) == 'function', 'co.start first arg must be function')

  local id = {}
  routines[id] = cocreate(func)

  local function continue(...)
    if not routines[id] then
      return
    end

    local ok,result = resume(routines[id], ...)
    assert(ok, 'Failed to resume coroutine')

    if type(result) == 'table' and result.next  then
      return result:next(function(value)
        return continue(unpack(value))
      end, function(err)
        -- TODO: Add option to kill coroutine on error
        return continue(err)
      end)
    elseif type(result) == 'function' then
      routines[id] = cocreate(result)
      return continue()
    end

    routines[id] = nil
  end

  continue(...)

  return id
end

function co.stop(id)
  routines[id] = nil
end

return co
