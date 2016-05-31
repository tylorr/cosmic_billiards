local list = {}

do
  local function appendHelper(value, n, first, ...)
    if n == 0 then
      return value
    else
      return first, appendHelper(value, n - 1, ...)
    end
  end

  function list.append(value, ...)
    return appendHelper(value, select('#', ...), ...)
  end
end

return list
