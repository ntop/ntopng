--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json  = require "dkjson"

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
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> This flow cannot be found (expired ?)</div>")
else

   if((type == nil) or (type == "size")) then
      if((mode == nil) or (mode == "sent")) then
	 what = host["pktStats.sent"]["size"]
      else
	 what = host["pktStats.recv"]["size"]
      end
   end

   local tot = 0
   for key, value in pairs(what) do
      tot = tot + value
   end

   local threshold = (5 * tot) / 100

   local s = 0
   for key, value in pairs(what) do
      if(value > threshold) then
	 res[#res + 1] = {label = key, value = value}
	 s = s + value
      end
   end

   if tot > s then
      res[#res + 1] = {label = "Other", value = (tot - s)}
   end
end

print(json.encode(res))
