local functional = {}

function functional.map(tbl, func)
  local result = {}
  for k,v in pairs(tbl) do
    result[k] = func(v, k, tbl)
  end
  return result
end

 function functional.filter(tbl, func)
  local result = {}
  for k,v in pairs(tbl) do
    if func(v, k) then
      result[k] = v
    end
  end
  return result
 end

function functional.flatten(array, shallow)
  local result = {}
  for _,value in pairs(array) do
    if type(value) == 'table' then
      local flatValue = shallow and value or functional.flatten(value)
      for _,flatV in ipairs(flatValue) do
        result[#result + 1] = flatV
      end
    else
      result[#result + 1] = value
    end
  end
  return result
end

function functional.every(tbl, fn)
  for _,value in pairs(tbl) do
    if not fn(value) then return false end
  end
  return true
end

function functional.identity(x) return x end

function functional.bind(func, arg1)
  return function(...) func(arg1, ...) end
end

return functional
