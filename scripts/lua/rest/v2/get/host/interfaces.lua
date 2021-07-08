--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")

--
-- Retrieves all ntopng interfaces of a given host
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"host" : "192.168.1.1"}' http://localhost:3000/lua/rest/v2/get/host/interfaces.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local host_info = url2hostinfo(_GET)

if isEmptyString(host_info["host"]) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

local host_key = hostinfo2hostkey(host_info)
-- Use the host as key in the response so it will be easier to extend
-- this endpoint with multiple hosts if necessary
res[host_key] = {}

for ifid, _ in pairs(interface.getIfNames()) do
   -- Possibly allowerd interface already enforced by iterator
   interface.select(ifid)
   local cur_host_info = interface.getHostInfo(host_key)

   if cur_host_info then
      -- Host found on the given interface
      res[host_key][#res[host_key] + 1] = {ifid = interface.getId()}
   end
end

rest_utils.answer(rc, res)

