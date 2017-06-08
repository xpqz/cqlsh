--[[
   Copyright 2017 Stefan Kruger

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
--]]

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

