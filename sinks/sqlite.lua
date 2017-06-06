--- A Sink for SQLite3
local sqlite3 = require 'lsqlite3'
local json = require 'cjson'

local unpack = unpack or table.unpack -- 5.1 compat

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
  tbl.rows = {}

  tbl.insert_document = assert(tbl.db:prepare('INSERT INTO documents (_id, _rev, body) VALUES (?, ?, json(?))'))
  tbl.insert_seq = assert(tbl.db:prepare('INSERT INTO local (last_seq) VALUES (?)'))

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
  if #self.rows > 0 then
    self.db:exec 'BEGIN TRANSACTION'
    for _, row in ipairs(self.rows) do
      local doc = row.doc
      execute{statement=self.insert_document, data={doc._id, doc._rev, json.encode(doc)}}
    end
    execute{statement=self.insert_seq, data={self.rows[#self.rows].seq}}
    self.db:exec 'COMMIT'
    self.rows = {}
  end
end

function Sink:absorb(row)
  if #self.rows == self.chunk then
    self:commit_chunk()
  end
  self.rows[#self.rows+1] = row
end

function Sink:drain()
  self:commit_chunk()
end

return Sink