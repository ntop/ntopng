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
-- Example: curl -u admin:admin -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/flow/l7/counters.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   print(rest_utils.rc(rest_utils.consts.err.invalid_interface))
   return
end

interface.select(ifid)

local flowstats = interface.getActiveFlowsStats()
local l7_proto = flowstats["ndpi"]

for k,v in pairsByKeys(l7_proto, asc) do
   res[#res + 1] = {
      name = k,
      count = v.num_flows,
   }
end

print(rest_utils.rc(rc, res))

