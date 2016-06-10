local iter = {}

local function stride(step)
  return function(a, i)
    i = i + step
    local v = a[i]
    if v ~= nil then
      return i, v
    end
  end
end

function iter.evens(a)
  return stride(2), a, 0
end

function iter.odds(a)
  return stride(2), a, -1
end

function iter.yield(x)
  return coroutine.yield, x, nil
end

return iter
