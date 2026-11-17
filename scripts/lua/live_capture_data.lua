--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local format_utils = require "format_utils"
local json = require "dkjson"

interface.select(ifname)

sendHTTPHeader('application/json')

local result = {}

local perPage = 5
local currentPage = 1
local total_rows = 1

result["perPage"] = perPage
result["currentPage"] = currentPage
local lc = interface.dumpLiveCaptures()
local res = {}


for k,v in pairs(lc) do
   local host = ""
   local num_captured_packets = format_utils.formatValue(v.num_captured_packets)
   local capture_max_pkts = v.capture_max_pkts
   local diff = v.capture_until - os.time()
   local capture_until = format_utils.formatEpoch(v.capture_until).." [ - "..diff.." sec ]"
   -- POST with the CSRF token: a GET to stop_live_capture.lua is refused
   local stop_href = "<form class=\"d-inline\" method=\"post\" action=\"".. ntop.getHttpPrefix() .."/lua/stop_live_capture.lua?capture_id="..v.id.."\"><input type=\"hidden\" name=\"csrf\" value=\""..ntop.getRandomCSRFValue().."\"><button type=\"submit\" class=\"badge bg-danger border-0\">Stop <i class=\"fas fa-download\"></i></button></form>"

   if(v.host ~= nil) then host = v.host end
   res[#res + 1] = { host = host, num_captured_packets = num_captured_packets, capture_until = capture_until, stop_href = stop_href }
end

result["data"] = res
result["totalRows"] = #res

result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))
