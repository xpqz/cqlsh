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

--- A Source for Cloudant
local json = require 'cjson'
local request = require 'http.request'

local Source = { 
  username = '',
  password = '',
  interval = 1000,
  url = nil
}

--- A Source for Cloudant
-- @param database The name of the database file. Use ':memory:' for a temporary db
-- @usage local source = Source:new{url='https://account.cloudant.com', username='user', password='pass', database="routes"}
-- @return table
function Source:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.url)

  -- TODO: figure out how sessions work
  local match = string.match(tbl.url, '(https://)([^:@]+)')
  if match and tbl.username ~= '' and tbl.password ~= '' then
    tbl.url = match[1] .. tbl.username .. ':' .. tbl.password .. '@' .. match[2]
  end

  if string.sub(tbl.url, -1) ~= '/' then
    tbl.url = tbl.url .. '/'
  end

  return tbl
end

function Source:emit_next()
  local req = request.new_from_uri(string.format('%s/_changes?feed=continuous&style=main_only&include_docs=true&seq_interval=%d&timeout=0', self.url, self.interval))
  local headers, stream = req:go()

  local index = 1

  while true do
    local line = stream:get_body_until('\n', true, false)
    if not line then break end
    if line ~= '' then
      local row = json.decode(line) 
      coroutine.yield(index, row)
      if row.last_seq then break end
      index = index + 1
    end
  end
end

--- Co-routine for listing all documents
function Source:emit()
  return coroutine.wrap(function() self:emit_next() end)
end

return Source