--- A Sink for a file on disk
local json = require 'cjson'

local Sink = { filename = nil, chunk=500 }

function Sink:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.filename)
  local file, err = io.open(tbl.filename, "wb")
  if err then return err end
  tbl.fp = file
  
  tbl.docs = {}

  return tbl
end

function Sink:commit_chunk()
  if #self.docs > 0 then 
    self.fp:write(json.encode(self.docs))
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