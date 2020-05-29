--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local rest_utils = require("rest_utils")

--
-- Read number of alerts per type
-- Example: curl -u admin:admin -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/alert/type/counters.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts_ok
local res = {}

local ifid = _GET["ifid"]
local what = _GET["status"] -- historical, historical-flows
local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]

if isEmptyString(ifid) then
   print(rest_utils.rc(rest_utils.consts_invalid_interface))
   return
end

interface.select(ifid)

if isEmptyString(what) or what == "historical" then
   local h_by_type = alert_utils.getNumAlertsPerType("historical", epoch_begin, epoch_end)
   for k,v in pairs(h_by_type, asc) do
      v.type = alert_consts.alertTypeRaw(v.id)
      v.id = nil
   end
   res['historical'] = h_by_type
end

if isEmptyString(what) or what == "historical-flows" then
   local hf_by_type = alert_utils.getNumAlertsPerType("historical-flows", epoch_begin, epoch_end)
   for k,v in pairs(hf_by_type, asc) do
      v.type = alert_consts.alertTypeRaw(v.id)
      v.id = nil
   end
   res['historical-flows'] = hf_by_type
end

print(rest_utils.rc(rc, res))

