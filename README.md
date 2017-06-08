## Cqlsh – a data transformation tool for CouchDB

`cqlsh` is a data transformation pipeline that can read data from, and write to e.g. CouchDB, flat files, sqlite3 databases.

## Usage

    # Dump data from Cloudant to a json-like file
    % ./cqlsh --source 'https://skruger.cloudant.com/routes' --sink routes.json --verbose
    [source] remote Cloudant: https://skruger.cloudant.com/routes
    [sink]   local file: test.json
    [source] emitted 2013 records

    # Dump data from Cloudant to a sqlite3 database, utilising its json1 extension
    % ./cqlsh --source 'https://skruger.cloudant.com/routes' --sink routes.db --verbose
    [source] remote Cloudant: https://skruger.cloudant.com/routes
    [sink]   SQLite3 database: routes.db
    [source] emitted 2013 records

    # Dump data from Cloudant as json to stdout
    % ./cqlsh --source 'https://skruger.cloudant.com/routes' --sink - | more 

## Installation

A Vagrant file is provided. If you want to run it locally, you need to ensure that you build the `lsqlite3` rock
against a sqlite3 that has the json1 extension enabled. Note that the SQLite3 installed by default on many systems
do not enable the json1 extension. In such cases, download the SQLite3 source code and point `luarocks` to this dir
manually:

    % sudo luarocks install lsqlite3 SQLITE_DIR=/path/to/latest/sqlite3

On OS/X you can install a modern `sqlite3` via `brew`:

    % brew install sqlite3
    % sudo luarocks install lsqlite3 SQLITE_DIR=/usr/local/opt/sqlite3

## Dependencies

* lua-cjson
* lsqlite3
* lua-http
* argparse

## Options

    --source   - where to read data from: URL | filename.[json|db]
    --sink     - where to write data to: filename.[json|db] | -
    --username - Cloudant account/API key (for Cloudant source)
    --password - Cloudant password (for Cloudant source)
    --chunk    - number of docs to process per iteration
    --index    - field name to generate index for (for sqlite3 sink)
    --verbose  - some basic info

## JSON format

If you dump data to a file, it will contain a json-array per line, but the file itself will not be valid json.
Each line will be a json-array contaning at most `chunk` records. To process such a file in Lua, you could do
something like:

    ```lua
    local json = require 'cjson'
    for line in io.lines(filename) do
        for _, record in ipairs(json.decode(line)) do
            -- do something with record
        end
    end
    ```
    
## Using the SQLite3 json1 extension to query json documents

The schema employed is pretty simple:

    ```sql    
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
    ```

The document itself is simply a text field in the `documents` table. The second table
holds Cloudant sequence ids for its changes feed, giving the option to resume from the
first new document (WIP).

In SQLite3, you can index on arbitrary expressions, including those provided by the json1 
extension. If you specify fields to be indexed, the indexes will be generated using the 
statement:

    ```sql
    CREATE INDEX '{fieldname}' ON documents(json_extract(body, '$.{fieldname}'));
    ```

where `fieldname` is the field in the json body for which the index was requested. The `$`
anchors the expression to the top-level of the json-object. In order to access a nested
field, e.g. the country in the following doc:

    ```json
    {
        '_id': '7a36cbc16e43e362e1ae68861abfb1ec',
        '_rev': '1-7d0f95d893ba26ae0d7949707022b03f',
        'address': {
            'street': '1366 Main St',
            'city': 'Boston',
            'zip': '02134',
            'country': 'USA'
        }
    }
    ```

you'd use `$.address.country`.

In the `routes` database above, to find all routes on the `Stanage` crag:

    ```sql
    SELECT _id, json_extract(body, '$.crag'), json_extract(body, '$.name') 
        FROM documents WHERE json_extact(body, '$.crag') = 'Stanage';
    ```

If you have requested the indexes to be created, you can verify that your queries hit them, e.g.

    ```
    sqlite> explain query plan select _id, json_extract(body, '$.crag'), json_extract(body, '$.name') 
        ...> from documents where json_extract(body, '$.crag') = 'Stanage';
    0|0|0|SEARCH TABLE documents USING INDEX crag (<expr>=?)
    sqlite> 
    ```

The json1 extension is fast and light-weight. For further information, consult the documentation
on the sqlite3 (site)[https://sqlite.org/json1.html].

## Performance

The Cloudant source streams the changes feed in continuous mode, picking only winning leaves, and asking
for sequence id generation one per batch. It's a pretty efficient way of getting data out of Cloudant.

The SQLite3 sink can deal with reasonably large data volumes. 

As a purely anectdotal example, streaming a 14G database with just over 21.5M docs from the Dallas datacenter 
to my laptop in Bristol, generating two indexes, 10,000 docs at a time:

    % time ./cqlsh --source 'https://skruger.cloudant.com/simple_geoplaces' --sink geo.db \
                   --index properties.city --index properties.country --chunk 10000

    real	117m51.399s
    user	30m20.001s
    sys	    14m16.393s

which produced a sqlite3 db:

    stefans-mbp:cqlsh stefan$ ls -als geo.db
    39860752 -rw-r--r--  1 stefan  staff  20408705024  8 Jun 16:22 geo.db

Lua 5.2.4, sqlite3 3.19.2