--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils   = require "rest_utils"
local alert_consts = require "alert_consts"

--
-- Returns the list of alert type definitions (key, string, name, attacker/victim flags, status key).
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/alert_definitions.lua
--

local res = {}

for alert_key = 0, 65535 do
   local alert_type = alert_consts.getAlertType(alert_key)

   if alert_type and alert_consts.alert_types[alert_type] then
      local def = alert_consts.alert_types[alert_type]
      local entry = {
         alert_key  = alert_key,
         alert_type = alert_type,
      }

      if def.meta then
         entry.name         = alert_consts.alertTypeLabel(alert_key, true) or ""
         entry.has_attacker = def.meta.has_attacker == true
         entry.has_victim   = def.meta.has_victim   == true
         entry.status_key   = def.meta.status_key
      else
         entry.to_be_migrated = true
      end

      res[#res + 1] = entry
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
