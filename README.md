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
against a sqlite3 that has the json1 extension enabled.