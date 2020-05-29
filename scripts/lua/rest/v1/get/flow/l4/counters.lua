--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--
-- Read number of active flows per protocol
-- Example: curl -u admin:admin -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/flow/l4/counters.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   print(rest_utils.rc(rest_utils.consts_invalid_interface))
   return
end

interface.select(ifid)

local flowstats = interface.getActiveFlowsStats()
local l4_proto = flowstats["l4_protocols"]

for k,v in pairs(l4_proto, asc) do
   res[#res + 1] = {
      id = k,
      count = v.count,
   }
end

print(rest_utils.rc(rc, res))

