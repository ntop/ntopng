--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local auth = require "auth"
local rest_utils = require "rest_utils"
local alert_consts = require "alert_consts"
local all_alert_store = require "all_alert_store".new()

--
-- Read alerts count by time
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/alert/severity/counters.lua
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

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = all_alert_store:get_counters_by_severity()

local top_alerts = {}

for _, value in ipairs(res) do
   top_alerts[#top_alerts + 1] = {
      count = tonumber(value.count),
      entity_id = tonumber(value.entity_id),
      entity_label = alert_consts.alertEntityLabel(value.entity_id),
      alert_id = tonumber(value.alert_id),
      name = i18n(alert_consts.alertSeverityById(tonumber(value.severity)).i18n_title),
   }
end

rest_utils.answer(rc, top_alerts)
