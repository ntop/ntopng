--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local alert_utils = require "alert_utils"
local alert_consts = require "alert_consts"
local alert_entities = require "alert_entities"
local rest_utils = require("rest_utils")
local all_alert_store = require "all_alert_store".new()
local alert_severities = require "alert_severities"
local auth = require "auth"

--
-- Read alerts count by time
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/host/alert/ts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

local ifid = _GET["ifid"]

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local res = {
   series = {},
   colors = {}
}

local count_data = all_alert_store:count_by_severity_and_time(true)

for _, severity in pairsByField(alert_severities, "severity_id", rev) do
   if(count_data[severity.severity_id] ~= nil) then
      res.series[#res.series + 1] = {
	 name = i18n(severity.i18n_title),
	 data = count_data[severity.severity_id],
      }
      
      res.colors[#res.colors + 1] = severity.color
   end
end

rest_utils.answer(rc, res)
