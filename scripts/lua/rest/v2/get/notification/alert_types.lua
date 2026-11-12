--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Alert types a recipient can be restricted to, per entity (page-notifications.vue loads it
-- only when "specific alerts" is chosen). Values: "<alert_id>_<entity_id>" as stored in the
-- recipient checks, plus the i18n key of the alert name.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/notification/alert_types.lua"
--

-- http_lint (validates _GET, loads ntop_utils: isAdministrator, pairsByField, asc): lua_utils not needed
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local alert_consts = require "alert_consts"
local alert_entities = require "alert_entities"

local res = {}
for key, entity in pairsByField(alert_entities, "entity_id", asc) do
   local entity_id = entity.entity_id
   local alerts = {}

   for alert_id, alert_key in pairs(alert_consts.getAlertTypes(entity_id) or {}) do
      local type_info = alert_consts.alert_types[alert_key]
      -- Definitions under alert_definitions/other are registered also under their meta.entities
      -- (e.g. disk space low under system): list them only there, not again under "other"
      local shared = type_info and type_info.meta and type_info.meta.entities
      if type_info and not (shared and entity_id == alert_entities.other.entity_id) then
         alerts[#alerts + 1] = {
            id = string.format("%d_%d", alert_id, entity_id),
            i18n_title = (type_info.meta and type_info.meta.i18n_title) or type_info.i18n_title or alert_key,
         }
      end
   end

   if #alerts > 0 then
      res[#res + 1] = { entity = key, i18n_label = entity.i18n_label, alerts = alerts }
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
