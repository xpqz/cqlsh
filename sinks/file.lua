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

--- A Sink for a file on disk
local json = require 'cjson'

local Sink = { filename = nil, chunk=500 }

function Sink:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.filename)

  if tbl.filename == '-' then
    tbl.fp = io.stdout
  else 
    local file, err = io.open(tbl.filename, "wb")
    if err then return err end
    tbl.fp = file
  end
  
  tbl.docs = {}

  return tbl
end

function Sink:commit_chunk()
  if #self.docs > 0 then 
    self.fp:write(json.encode(self.docs), "\n")
    self.docs = {}
  end
end

function Sink:absorb(row)
  if #self.docs == self.chunk then 
   self:commit_chunk()
  end
  self.docs[#self.docs+1] = row.doc
end

function Sink:drain()
  self:commit_chunk()
end

return Sink