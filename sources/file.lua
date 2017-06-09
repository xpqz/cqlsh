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

--[[ 
  A Source for file on disk.
  The file is assumed to be composed of lines where each line
  is a json-array of json-objects:

  [{'_id':'123abc','_rev':'..'},{..},..]
  [{'_id':'234cde','_rev':'..'}]

  Lines can be of different lenghts
--]]
local json = require 'cjson'

local Source = { filename = nil }

function Source:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.filename)
  
  return tbl
end

function Source:emit_next()
  local line
  local index = 1
  for line in io.lines(self.filename) do
    for _, doc in ipairs(json.decode(line)) do
      coroutine.yield(index, doc)
      index = index + 1
    end
  end
end

--- Co-routine for listing all documents
function Source:emit()
  return coroutine.wrap(function() self:emit_next() end)
end

return Source