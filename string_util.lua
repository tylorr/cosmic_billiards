local stringUtil = {}

function stringUtil.uppercaseFirst(str)
  return (str:gsub('^%l', string.upper))
end

function stringUtil.lowercaseFirst(str)
  return (str:gsub('^%u', string.lower))
end

return stringUtil
