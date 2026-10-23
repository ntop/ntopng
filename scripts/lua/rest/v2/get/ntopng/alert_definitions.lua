--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils     = require "rest_utils"
local auth           = require "auth"
local alert_consts   = require "alert_consts"
local alert_entities = require "alert_entities"

--
-- Returns the list of alert type definitions (key, entity, string, name, attacker/victim flags, status key).
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/alert_definitions.lua
--

-- Developer pages (Developer > Catalog): users with the developer capability
if not auth.has_capability(auth.capabilities.developer) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- Alert keys are unique only within an entity (flow and host alerts share
-- them): list the definitions per entity, the directory they come from.
-- 'other' first: its definitions may also be registered for other entities
-- (meta.entities), each definition is listed once
local by_entity = alert_consts.getAlertTypesByEntity()
local res       = {}
local listed    = {}

for _, entity in ipairs({ alert_entities.other, alert_entities.flow, alert_entities.host }) do
   local entity_label = i18n(entity.i18n_label) or entity.i18n_label

   for alert_key, alert_type in pairs(by_entity[entity.entity_id] or {}) do
      local def = alert_consts.alert_types[alert_type]

      if def and not listed[alert_type] then
         local entry = {
            alert_key  = alert_key,
            entity     = entity_label,
            alert_type = alert_type,
         }

         listed[alert_type] = true

         if def.meta then
            local title = def.meta.i18n_title or def.i18n_title

            entry.name         = (title and (i18n(title) or title)) or ""
            entry.has_attacker = def.meta.has_attacker == true
            entry.has_victim   = def.meta.has_victim   == true
            entry.status_key   = def.meta.status_key
         else
            entry.to_be_migrated = true
         end

         res[#res + 1] = entry
      end
   end
end

-- Same order of the old key scan: by alert key, then entity
table.sort(res, function(a, b)
   if a.alert_key ~= b.alert_key then return a.alert_key < b.alert_key end
   return a.entity < b.entity
end)

rest_utils.answer(rest_utils.consts.success.ok, res)
