local sqlite3 = require 'lsqlite3'
local json = require 'cjson'
local argparse = require 'argparse'
local request = require 'http.request'
local os = require 'os'

local function filter(doc)
  if string.sub(doc._id, 1, string.len('_design')) == '_design' then
    return nil
  end
  return doc
end

local function create_db(database, indexes)
  local schema = [[
    CREATE TABLE IF NOT EXISTS documents (
      _id TEXT NOT NULL,
      _rev TEXT NOT NULL,
      body TEXT,
      UNIQUE (_id, _rev) ON CONFLICT IGNORE
    );
    CREATE TABLE IF NOT EXISTS local (
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

local function execute(arg)
  assert(arg.statement)
  assert(arg.data)
  
  arg.statement:reset()
  local status = arg.statement:bind_values(unpack(arg.data))
  if status ~= sqlite3.OK then
    error(string.format("An error occurred: %d", status))
  end
  
  -- option to execute insert, update and deletes directly
  if arg.step then
    status = arg.statement:step() 
    if status ~= sqlite3.DONE then
      error(string.format("An error occurred: %d", status))
    end
  end
  
  return true
end

local function commit_chunk(db, docs, statement)
  db:exec 'BEGIN TRANSACTION'
  for _, doc in ipairs(docs) do
    local _id = doc._id
    local _rev = doc._rev
    doc._id = nil
    doc._rev = nil
    execute{statement=statement, data={_id, _rev, json.encode(doc)}, step=true}
  end
  db:exec 'COMMIT'
end

local parser = argparse('cqlsh', 'Load a CouchDB database into sqlite3')
parser:option('-u --url', 'Base couchdb URL', '')
parser:option('-d --database', 'database', '')
parser:option('-c --chunk', 'commit size', 1000)
parser:option("-i --index", 'index json fields', {}):count '*'

local args = parser:parse()

if args.url == '' then
  if os.getenv('COUCH_URL') then 
    args.url = os.getenv('COUCH_URL') 
  else
    print('No URL given!!')
    os.exit(1)
  end
end

if args.database == '' then
  if os.getenv('COUCH_DATABASE') then 
    args.database = os.getenv('COUCH_DATABASE')
  else
    print('No database given!')  
    os.exit(2)
  end
end

print(unpack(args.index))

-- Set up target
local db = assert(create_db(sqlite3.open(args.database .. '.db'), args.index))

-- fetch
local req = request.new_from_uri(string.format('%s/%s/_changes?feed=continuous&style=main_only&include_docs=true&timeout=0', args.url, args.database))
local headers, stream = req:go()

local docs = {}
local insert_document = assert(db:prepare('INSERT INTO documents (_id, _rev, body) VALUES (?, ?, json(?))'))

while true do
  local line = stream:get_body_until('\n', true, false)
  if not line then break end
  if line ~= '' then
    if #docs == args.chunk then
      print('.')
      commit_chunk(db, docs, insert_document)
      docs = {}
    end
    local row = json.decode(line) 
    if row.last_seq then 
      break 
    end
    filtered = filter(row.doc)
    if filtered ~= nil then
      docs[#docs+1] = row.doc
    end
  end
end

if #docs > 0 then
  commit_chunk(db, docs, insert_document)
end


