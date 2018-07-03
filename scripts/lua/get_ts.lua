--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require("ts_utils")
local json = require("dkjson")

local schema_id = _GET["ts_schema"]
local query = _GET["ts_query"]
local tstart = tonumber(_GET["epoch_begin"]) or (os.time() - 3600)
local tend = tonumber(_GET["epoch_end"]) or os.time()

-- convert the query into fields
local tags = tsQueryToTags(_GET["ts_query"])

if tags.ifid then
  interface.select(tags.ifid)
end

sendHTTPHeader('application/json')

-- Load all the schemas
require("ts_second")
require("ts_minute")
require("ts_5min")

local res = ts_utils.query(schema_id, tags, tstart, tend)

if not res then
  print("[]")
end

print(json.encode(res))
