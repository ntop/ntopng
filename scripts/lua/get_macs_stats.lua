--
-- (C) 2013-22 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "mac_utils" -- needed for the function mac2record
local json = require("dkjson")

sendHTTPContentTypeHeader('text/html')
-- sendHTTPHeader('application/json')

interface.select(ifname)

local hosts = _GET["hosts"]

local res = {}

if not isEmptyString(hosts) then

   local items = split(hosts, ',')

   for _, item in pairs(items) do
      local host_info = hostkey2hostinfo(item)

      if host_info["host"] ~= nil then
         local host = interface.getMacInfo(host_info["host"])

         if host then
            res[item] = mac2record(host)
         end
      end
   end

end

print(json.encode(res, nil))
