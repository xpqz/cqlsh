--[[------------------------------------------------------------------------
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
--]]------------------------------------------------------------------------

--- A Source for SQLite3
local sqlite3 = require 'lsqlite3'
local json = require 'cjson'
local posix = require 'posix'

local unpack = unpack or table.unpack -- 5.1 compat

local Source = { database = nil }

--- A Source for SQLite3
-- @param database The name of the database file
-- @usage local sqlite = Source:new{database='routes.db'}
-- @return table
function Source:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.database)
  assert(posix.stat(tbl.database)) -- file must exist
  tbl.db = assert(sqlite3.open(tbl.database))
  tbl.rows = {}

  return tbl
end

function Source:emit_next()
  local index = 1
  for row in self.db:nrows('SELECT * FROM documents') do
    coroutine.yield(index, {seq=nil, doc=json.decode(row.body)})
    index = index + 1
  end
end

--- Co-routine for listing all documents
function Source:emit()
  return coroutine.wrap(function() self:emit_next() end)
end

return Source