local Cloudant = require 'source'
local SQLite3 = require 'sink'
local Pipe = require 'pipeline'

local argparse = require 'argparse'
local os = require 'os'
local json = require 'cjson'

local parser = argparse('cqlsh', 'Load a CouchDB database into sqlite3')
parser:option('-u --url', 'Base couchdb URL', '')
parser:option('-d --database', 'database', '')
parser:option('--user', 'username', '')
parser:option('--password', 'password', '')
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

-- Optional username and password. If not given, check the COUCH_USER and COUCH_PASSWORD 
-- environment variables. If not given, proceed anyway as source URL can have the access
-- creds inline, or the resource may be open for unauthenticated reading.
if args.user == '' then
  if os.getenv('COUCH_USER') then 
    args.user = os.getenv('COUCH_USER')
  end
end

if args.password == '' then
  if os.getenv('COUCH_PASSWORD') then 
    args.user = os.getenv('COUCH_PASSWORD')
  end
end

local pipeline = Pipe:new {
  source = Cloudant:new {
    url = args.url,
    username = args.username,
    password = args.password,
    database = args.database
  },
  sink = SQLite3:new {
    database = args.database,
    indexes = args.index,
    chunk = args.chunk
  },
  filters = {
    function (row) -- skip design documents
      if row == nil or row == {} or not row.doc then return nil end
      if string.sub(row.doc._id, 1, string.len('_design')) == '_design' then
        return nil
      end
      return row
    end
  }
}

pipeline:process()


