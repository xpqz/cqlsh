local Pipe = { 
  source = nil, 
  sink = nil,
  filters = {}
}

function Pipe:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.source)
  assert(tbl.sink)
  return tbl
end

function Pipe:process()
  for _, row in self.source:emit() do
    local filtered = row
    for _, filter in ipairs(self.filters) do
      filtered = filter(filtered)
    end
    if filtered ~= nil then
      self.sink:absorb(filtered)
    end
  end

  self.sink:drain()
end

return Pipe

