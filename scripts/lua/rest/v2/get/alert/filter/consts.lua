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
local alert_severities = require "alert_severities"
local alert_utils = require "alert_utils"
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

local filters = alert_store_instance:get_available_filters()

for id, v in pairs(filters) do 
   local filter = {
      id = id,
      label = v.i18n_label,
      value_type = v.value_type,
      value_label = v.value_i18n_label or v.i18n_label,
      operators = {}
   }

   for _, op in ipairs(v.operators) do
      filter.operators[#filter.operators+1] = {
         id = op,
         label = tag_utils.tag_operators[op],
      }
   end

   -- select (array of values)
   if v.value_type == "alert_id" then
      filter.value_type = 'array'
      filter.options = {}
      for _, alert_type in pairsByValues(all_alert_types, alert_consts.alert_type_info_asc) do
         filter.options[#filter.options+1] = {
            value = alert_type.alert_id,
            label = alert_type.label,
         }
      end
   elseif v.value_type == "l7_proto" then
      filter.value_type = 'array'
      filter.options = {}
      local l7_protocols = interface.getnDPIProtocols()
      for name, id in pairsByKeys(l7_protocols, asc) do
         filter.options[#filter.options+1] = { value = id, label = name, }
      end
   elseif v.value_type == "ip_version" then
      filter.value_type = 'array'
      filter.options = {}
      filter.options[#filter.options+1] = { value = "4", label = i18n("ipv4"), }
      filter.options[#filter.options+1] = { value = "6", label = i18n("ipv6"), }
   elseif v.value_type == "role" then
      filter.value_type = 'array'
      filter.options = {}
      filter.options[#filter.options+1] = { value = "attacker", label = i18n("attacker"), }
      filter.options[#filter.options+1] = { value = "victim",   label = i18n("victim"),   }
      filter.options[#filter.options+1] = { value = "no_attacker_no_victim", label = i18n("no_attacker_no_victim"),
      }
   elseif v.value_type == "role_cli_srv" then
      filter.value_type = 'array'
      filter.options = {}
      filter.options[#filter.options+1] = { value = "client", label = i18n("client"), }
      filter.options[#filter.options+1] = { value = "server", label = i18n("server"), }
   elseif v.value_type == "severity" then
      filter.value_type = 'array'
      filter.options = {}
      local severities = alert_severities
      for _, severity in pairsByValues(severities, alert_utils.severity_rev) do
         filter.options[#filter.options+1] = {
            value = severity.severity_id,
            label = i18n(severity.i18n_title),
         }
      end
   end

   res[#res+1] = filter
end

rest_utils.answer(rest_utils.consts.success.ok, res)
