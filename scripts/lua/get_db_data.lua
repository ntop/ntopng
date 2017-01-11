--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "db_utils"
local json = require ("dkjson")

local ifId        = _GET["ifId"]
local ip_version  = _GET["version"]
local host        = _GET["host"]
local epoch_end   = tonumber(_GET["epoch_end"]   or os.time())
local epoch_begin = tonumber(_GET["epoch_begin"] or epoch_end - 3600)
local l4proto     = _GET["l4proto"]
local l7proto     = _GET["l7proto"]
local profile     = _GET["profile"]
local port        = _GET["port"]
local info        = _GET["info"]
local limit       = _GET["limit"]
local format      = _GET["format"]
local action      = _GET["action"]

if ip_version == nil then ip_version = "4" end
ip_version = tonumber(ip_version)

if epoch_begin> epoch_end then
   local tmp = epoch_end
   epoch_end = epoch_begin
   epoch_being = epoch_end
end
local timediff = epoch_end - epoch_begin + 1

local totals = { ["count"] = {}, ["timespan"] = timediff, ["status"] = "ok" }
local versions  = { [4] = 'IPv4', [6] = 'IPv6' }

headerShown = false

-- os.execute("sleep 30") -- this is to test slow responses

for k,v in pairs(versions) do
   local res = getNumFlows(_GET["ifId"], k, _GET["host"], _GET["l4proto"], _GET["port"], _GET["protocol"], _GET["info"], _GET["epoch_begin"], _GET["epoch_end"], _GET["limit"])

   if res == nil or res[1] == nil then
      totals["status"] = "error"
      totals["statusText"] = "Empty query response (database down or query killed/timed out?)"
      goto continue
   end

   res = res[1]  -- only one row is present in the result that contains the aggregate counters

   totals["count"][v] = {
      ["tot_flows"]   = tonumber(res["TOT_FLOWS"]) or 0,
      ["tot_bytes"]   = tonumber(res["TOT_BYTES"]) or 0,
      ["tot_packets"] = tonumber(res["TOT_PACKETS"]) or 0
   }

   ::continue::
end

sendHTTPHeader('application/json')
print(json.encode(totals, nil))
