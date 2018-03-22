--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "db_utils"
local json = require ("dkjson")

local prefs = ntop.getPrefs()

local ifId        = _GET["ifid"]
local host        = _GET["host"] or ""
local epoch_end   = tonumber(_GET["epoch_end"]   or os.time())
local epoch_begin = tonumber(_GET["epoch_begin"] or epoch_end - 3600)
local l4proto     = _GET["l4proto"]
local l7proto     = _GET["l7proto"]
local port        = _GET["port"]
local info        = _GET["info"]
local vlan        = _GET["vlan"]
local profile     = _GET["profile"]
local limit       = _GET["limit"]

if epoch_begin> epoch_end then
   local tmp = epoch_end
   epoch_end = epoch_begin
   epoch_being = epoch_end
end
local timediff = epoch_end - epoch_begin + 1

local totals = { ["count"] = {}, ["timespan"] = timediff, ["status"] = "ok" }
local versions  = { [4] = 'IPv4', [6] = 'IPv6' }

if host ~= "" then
   local isv6 = isIPv6Address(host)

   if(isv6) then
      versions  = { [6] = 'IPv6' }
      totals["count"]['IPv4'] = { ["tot_flows"] = 0, ["tot_bytes"] = 0, ["tot_packets"] = 0 }
   else
      versions  = { [4] = 'IPv4' }
      totals["count"]['IPv6'] = { ["tot_flows"] = 0, ["tot_bytes"] = 0, ["tot_packets"] = 0 }
   end
end

headerShown = false

-- os.execute("sleep 30") -- this is to test slow responses
for k,v in pairs(versions) do
   local res = getNumFlows(ifId, k, host, _GET["l4proto"], _GET["port"], _GET["protocol"], _GET["info"], _GET["vlan"], _GET["profile"], _GET["epoch_begin"], _GET["epoch_end"])

   if res == nil or res[1] == nil then
      totals["status"] = "error"
      totals["statusText"] = i18n("db_explorer.empty_query_response")
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

totals["aggregated_flows"] = (prefs.is_flow_aggregation_enabled == true)

sendHTTPHeader('application/json')
print(json.encode(totals, nil))
