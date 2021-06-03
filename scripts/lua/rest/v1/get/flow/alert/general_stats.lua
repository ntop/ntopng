--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local auth = require "auth"
local rest_utils = require "rest_utils"
local alert_consts = require "alert_consts"
local flow_alert_store = require "flow_alert_store".new()

--
-- Read alerts count by time
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v1/get/flow/alert/general_stats.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local res = flow_alert_store:get_stats()
local top_alerts = {}

for _, value in pairs(res.top.alert_id) do
   top_alerts[#top_alerts + 1] = {
      count = value.count,
      alert_name = alert_consts.alertTypeLabel(tonumber(value.alert_id), true),
   }
end   

-- Request from the frontend - to have them as array
res = { 
   { 
      label = i18n("alerts_dashboard.top_hosts"),
      tooltip = i18n("alerts_dashboard.tooltips.top_hosts"),
      value = {
         res.top.ip
      }
   },
   {
      label = i18n("alerts_dashboard.top_alerts"),
      tooltip = i18n("alerts_dashboard.tooltips.top_alerts"),
      value = {
         top_alerts
      }
   }
}

rest_utils.answer(rc, res)
