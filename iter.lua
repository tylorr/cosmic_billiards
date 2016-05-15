local M = {}

local function stepIter(step)
  return function(a, i)
    i = i + step
    local v = a[i]
    if v then
      return i, v
    end
  end
end

function M.evens(a)
  return stepIter(2), a, 0
end

function M.odds(a)
  return stepIter(2), a, -1
end

return M
