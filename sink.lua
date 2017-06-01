local sqlite3 = require 'lsqlite3'
local json = require 'cjson'

local Sink = { database = nil, indexes = {}, chunk=1000 }

local function create_db(database, indexes)
  local schema = [[
    CREATE TABLE IF NOT EXISTS documents (
      _id TEXT NOT NULL,
      _rev TEXT NOT NULL,
      body TEXT,
      UNIQUE (_id, _rev) ON CONFLICT IGNORE
    );
    CREATE TABLE IF NOT EXISTS local (
      sync_id INTEGER PRIMARY KEY,
      last_seq TEXT
    );
  ]]

  -- optional json indexes
  for _, field in ipairs(indexes) do
    schema = schema .. string.format("CREATE INDEX '%s' ON documents(json_extract(body, '$.%s'));", field, field)
  end

  assert(database:exec('BEGIN TRANSACTION;' .. schema .. 'COMMIT;'))
  return database
end

--- A Sink for SQLite3
-- @param database The name of the database, without any suffix.
-- @usage local sqlite = Sink:new{database="routes", indexes={'crag', 'name'}, chunk=500}
-- @return table
function Sink:new(tbl) 
  tbl = tbl or {}
  setmetatable(tbl, self)
  self.__index = self
  assert(tbl.database)
  assert(tbl.indexes)
  assert(tbl.chunk and tbl.chunk >= 1)
  tbl.db = assert(create_db(sqlite3.open(tbl.database .. '.db'), tbl.indexes))
  tbl.chunk = {}
  tbl.docs = {}

  tbl.insert_document = assert(tbl.db:prepare('INSERT INTO documents (_id, _rev, body) VALUES (?, ?, json(?))'))
  -- tbl.insert_seq = assert(tbl.db:prepare('INSERT INTO local (last_seq) VALUES (?)'))

  return tbl
end

local function execute(arg)
  assert(arg.statement)
  assert(arg.data)
  
  arg.statement:reset()
  local status = arg.statement:bind_values(unpack(arg.data))
  if status ~= sqlite3.OK then
    error(string.format("An error occurred: %d", status))
  end
  
  status = arg.statement:step() 
  if status ~= sqlite3.DONE then
    error(string.format("An error occurred: %d", status))
  end
  
  return true
end

function Sink:commit_chunk()
  self.db:exec 'BEGIN TRANSACTION'
  for _, doc in ipairs(self.docs) do
    local _id = doc._id
    local _rev = doc._rev
    doc._id = nil
    doc._rev = nil
    execute{statement=self.insert_document, data={_id, _rev, json.encode(doc)}}
  end
  self.db:exec 'COMMIT'
end

function Sink:absorb(row)
  if #self.docs == self.chunk then
    self:commit_chunk()
    self.docs = {}
  end
  self.docs[#self.docs+1] = row
end

function Sink:drain()
  if #self.docs > 0 then
    self:commit_chunk()
    self.docs = {}
  end
end

return Sink