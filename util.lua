local util = {}

function util.pack(...)
  return { n = select('#', ...); ... }
end

function util.unpack(t)
  return unpack(t, 1, t.n)
end

function util.switch(cases, casevar, ...)
  local func = cases[casevar] or cases.default
  if func then
    assert(type(func) == 'function', 'caseof only excepts table of functions')
    return func(casevar, ...)
  end
end

return util
