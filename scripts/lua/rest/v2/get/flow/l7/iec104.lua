--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local rest_utils = require("rest_utils")

--
-- Read number of active flows per protocol
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/flow/l7/counters.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.select(ifid)

local flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))

local res = {}

if(flow.iec104) then
   res = flow.iec104
end

rest_utils.answer(rc, res)
