--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPContentTypeHeader('application/json', 'attachment; filename="exported_data.json"')

local mode = _GET["mode"]
local ifId = _GET["ifid"]

interface.select(ifId)

if mode == "filtered" then
   local host_info = url2hostinfo(_GET)
   local host

   if not isEmptyString(host_info["host"]) then
      host = interface.getHostInfo(host_info["host"], host_info["vlan"] or 0)
   end

   print(json.encode(host or {}))

else
   local hosts_retrv_function
   local hosts_stats

   if mode == "all" then
      hosts_retrv_function = interface.getHostsInfo
   elseif mode == "local" then
      hosts_retrv_function = interface.getLocalHostsInfo
   elseif mode == "remote" then
      hosts_retrv_function = interface.getRemoteHostsInfo
   end

   if hosts_retrv_function then
      hosts_stats = hosts_retrv_function()
   end

   print(json.encode(hosts_stats or {}))
end
