--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local auth = require "auth"
local alert_entities = require "alert_entities"
local flowfilter_utils = require "flowfilter_utils"

--
-- Get list of available filters
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/alert/filter/consts.lua?page=flow
--

-- Same access as the alert lists
if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local page = _GET["page"] or 'all'

local res = {}

-- Only the store of the page (<alert_store_name>_alert_store.lua), not all of them;
-- the snmp one is pro only. Otherwise the filters of all the alerts
local entity = alert_entities[page]
local alert_store_instance

if entity and entity.alert_store_name
   and (entity.alert_store_name ~= "snmp_device" or (ntop.isPro and ntop.isPro())) then
   alert_store_instance = require(entity.alert_store_name .. "_alert_store").new()
else
   alert_store_instance = require "all_alert_store".new()
end

local filters = alert_store_instance:get_available_filters()

for id, v in pairs(filters) do
   -- FIXX rename l7_proto to l7proto in flow alert store for consistency
   if id == "l7_proto" then id = "l7proto" end

   local filter = flowfilter_utils.get_flowfilter_info(id, entity)

   res[#res+1] = filter
end

rest_utils.answer(rest_utils.consts.success.ok, res)
