--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local stats_utils = require("stats_utils")
local rest_utils = require("rest_utils")
local dscp_consts = require "dscp_consts"

--
-- Read DSCP statistics for a hsot
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host" : "192.168.56.103", "direction": "recv"}' http://localhost:3000/lua/rest/v2/get/host/dscp/stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

local ifid = _GET["ifid"]
local host_info = url2hostinfo(_GET)
local direction = _GET["direction"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

local received_stats = false
if direction == "recv" then
   received_stats = true
end

interface.select(ifid)

local res = {}
local tot = 0

local stats = interface.getHostInfo(host_info["host"], host_info["vlan"])

if stats == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

for key, value in pairsByKeys(stats.dscp, asc) do
   res[#res + 1] = {
      label = dscp_consts.ds_class_descr(key),
      value = ternary(received_stats, value['packets.rcvd'], value['packets.sent'])
   }
end

local collapsed = stats_utils.collapse_stats(res, 1)

rest_utils.answer(rc, collapsed)
