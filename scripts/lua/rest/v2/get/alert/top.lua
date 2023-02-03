--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local auth = require "auth"
local rest_utils = require "rest_utils"
local all_alert_store = require "all_alert_store".new()

--
-- Read alerts count by time
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/alert/top.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

local ifid = _GET["ifid"]
local action = _GET["action"]

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

local top_limit = all_alert_store:get_top_limit()
local alert_count = all_alert_store:count()
local top_alerts_by_count    = all_alert_store:format_top_alerts(all_alert_store:top_alert_id_historical_by_count(), alert_count)
local top_alerts_by_severity = all_alert_store:format_top_alerts(all_alert_store:top_alert_id_historical_by_severity())

local res = { 
   {
      name = 'top_alerts_by_count',
      label = i18n("alerts_dashboard.top_alerts_by_count"),
      tooltip = i18n("alerts_dashboard.tooltips.top_alerts"),
      value = top_alerts_by_count
   },
   {
      name = 'top_alerts_by_severity',
      label = i18n("alerts_dashboard.top_alerts_by_severity"),
      tooltip = i18n("alerts_dashboard.tooltips.top_alerts_by_severity"),
      value = top_alerts_by_severity
   },
}

rest_utils.answer(rc, res)
