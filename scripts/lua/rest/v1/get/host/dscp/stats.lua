--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local dscp_consts = require "dscp_consts"

--
-- Read DSCP statistics for a hsot
-- Example: curl -u admin:admin -d '{"ifid": "1", "host" : "192.168.56.103", "direction": "recv"}' http://localhost:3000/lua/rest/v1/get/host/dscp/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local direction = _GET["direction"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   print(rest_utils.rc(rc))
   return
end

local received_stats = false
if direction == "recv" then
   received_stats = true
end

interface.select(ifid)

local tot = 0

local stats = interface.getHostInfo(host_info["host"], host_info["vlan"])

if stats == nil then
   print(rest_utils.rc(rest_utils.consts.err.not_found))
   return
end

for key, value in pairsByKeys(stats.dscp, asc) do
   res[#res + 1] = {
      label = dscp_consts.ds_class_descr(key),
      value = ternary(received_stats, value['packets.rcvd'], value['packets.sent'])
   }
end

print(rest_utils.rc(rc, res))
