local Pipe = { 
  source = nil, 
  sink = nil,
  filters = {},
  emits = 0
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
    if row ~= nil then
      self.emits = self.emits + 1
      local filtered = row
      for _, filter in ipairs(self.filters) do
        filtered = filter(filtered)
      end
      if filtered ~= nil then
        self.sink:absorb(filtered)
      end
    end
  end

  self.sink:drain()
end

return Pipe

