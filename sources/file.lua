--- A Source for file on disk.
-- The file is assumed to be composed of lines where each line
-- is a json-array of json-objects:
--
-- [{'_id':'123abc','_rev':'..'},{..},..]
-- [{'_id':'234cde','_rev':'..'}]
--
-- Lines can be of different lenghts
local json = require 'cjson'

local Source = { filename = nil }

---
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
      -- print(json.encode(doc))
      coroutine.yield(index, {doc=doc})
      index = index + 1
    end
  end
end

--- Co-routine for listing all documents
function Source:emit()
  return coroutine.wrap(function() self:emit_next() end)
end

return Source