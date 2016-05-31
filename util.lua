local util = {}

function util.pack(...)
  return { n = select('#', ...); ... }
end

function util.unpack(t)
  return unpack(t, 1, t.n)
end

return util
