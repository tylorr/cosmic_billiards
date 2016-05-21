local stringUtil = {}

function stringUtil.uppercaseFirst(str)
  return (str:gsub('^%l', string.upper))
end

return stringUtil
