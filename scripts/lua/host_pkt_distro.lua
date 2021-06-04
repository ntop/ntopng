--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json  = require "dkjson"
local stats_utils = require("stats_utils")

sendHTTPContentTypeHeader('text/html')

local mode = _GET["direction"]
local type = _GET["distr"]
local host_info = url2hostinfo(_GET)
local ifid = _GET["ifid"]

interface.select(ifid)

local host = interface.getHostInfo(host_info["host"],host_info["vlan"])
local what = {}
local res = {}

if(host == nil) then
   print("<div class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> This flow cannot be found (expired ?)</div>")
else

   if((type == nil) or (type == "size")) then
      if((mode == nil) or (mode == "sent")) then
	 what = host["pktStats.sent"]["size"]
      else
	 what = host["pktStats.recv"]["size"]
      end
   end

   for key, value in pairs(what) do
      res[#res + 1] = {label = key, value = value}
   end
end

local collapsed = stats_utils.collapse_stats(res, 1, 5 --[[ threshold ]])

print(json.encode(collapsed))
