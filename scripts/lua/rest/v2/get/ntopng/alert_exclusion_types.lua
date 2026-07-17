--
-- (C) 2013-26 - ntop.org
--
-- Flow/host alert type definitions used by the alert-exclusions editor page-alert-exclusions.vue
--
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/alert_exclusion_types.lua
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils     = require "rest_utils"
local auth           = require "auth"
local alert_consts   = require "alert_consts"
local alert_entities = require "alert_entities"

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local function compare_label(a, b)
   if a and b then return a.label < b.label end
end

local flow_alert_types = alert_consts.getAlertTypesInfo(alert_entities.flow.entity_id)
table.sort(flow_alert_types, compare_label)

local host_alert_types = alert_consts.getAlertTypesInfo(alert_entities.host.entity_id)
table.sort(host_alert_types, compare_label)

rest_utils.answer(rest_utils.consts.success.ok, {
   flow_alert_types = flow_alert_types,
   host_alert_types = host_alert_types,
})
