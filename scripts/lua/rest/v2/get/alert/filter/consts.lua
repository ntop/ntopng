--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local alert_entities = require "alert_entities"
local alert_store_utils = require "alert_store_utils"
local alert_store_instances = alert_store_utils.all_instances_factory()
local alert_consts = require "alert_consts"
local tag_utils = require "tag_utils"

--
-- Get list of available filters
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/alert/filter/consts.lua?page=flow
--

local page = _GET["page"] or 'all'

local rc = rest_utils.consts.success.ok
local res = {}

local alert_store_instance
local all_alert_types = {}

if alert_entities[page] and alert_store_instances[alert_entities[page].alert_store_name] then
   alert_store_instance = alert_store_instances[alert_entities[page].alert_store_name]
   all_alert_types = alert_consts.getAlertTypesInfo(alert_entities[page].entity_id)
else
   alert_store_instance = require "all_alert_store".new()
end

local tags = alert_store_instance:get_available_filters()

for id, v in pairs(tags) do
   -- FIXX rename l7_proto to l7proto in flow alert store for consistency
   if id == "l7_proto" then id = "l7proto" end

   local filter = tag_utils.get_tag_info(id)

   -- select (array of values)
   if filter.value_type == "alert_id" then
      filter.value_type = 'array'
      filter.options = {}
      for _, alert_type in pairsByValues(all_alert_types, alert_consts.alert_type_info_asc) do
         filter.options[#filter.options+1] = {
            value = alert_type.alert_id,
            label = alert_type.label,
         }
      end
   end

   res[#res+1] = filter
end

rest_utils.answer(rest_utils.consts.success.ok, res)
