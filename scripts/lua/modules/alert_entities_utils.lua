--
-- (C) 2020-24 - ntop.org
--

local alert_entities_utils = {}
local alert_entities = require "alert_entities"

function alert_entities_utils.alertEntity(id)
   local entity_id = -1
   if alert_entities[id] then
      entity_id = alert_entities[id].entity_id
   end

   return entity_id
end

return alert_entities_utils
