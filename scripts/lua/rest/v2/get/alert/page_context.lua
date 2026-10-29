--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Context of the Alerts Explorer SPA page (page-alert-stats-route.vue): the data the old
-- alert_stats.lua computed for PageAlertStats. Only raw values (i18n keys, no labels).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/alert/page_context.lua?ifid=0&page=flow&query_preset="
--

-- http_lint (validates _GET) + the light modules of rest_utils, not the whole lua_utils
require "http_lint"
local rest_utils = require "rest_utils"
local auth = require "auth"

-- Same access as alert_stats.lua and its REST APIs
if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(ifid)
end

-- interface.select() falls back to an allowed interface: refuse the others
if isEmptyString(ifid) or tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local page = _GET["page"] or "all"
local is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false
local is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false
local has_clickhouse = hasClickHouseSupport()
-- lightview (?view=lightview): alerts of all the interfaces (ClickHouse only)
local is_lightview = isLightView() and ntop.isClickHouseEnabled()

-- n2disk traffic extraction (not per interface: never in lightview). Both recording_utils
-- checks need this key: without it the module (~7 ms) is not loaded
local traffic_extraction_available = false
if not is_lightview and ntop.getCache("ntopng.cache.traffic_recording_available") == "1" then
   local recording_utils = require "recording_utils"
   local master_ifid = interface.getMasterInterfaceId()
   traffic_extraction_available = recording_utils.isActive(master_ifid) or recording_utils.isExtractionActive(master_ifid)
end

-- Columns of a custom query preset (scripts/historical/alerts/<page>), Enterprise L only
local columns_def = nil
local query_preset = _GET["query_preset"]

if is_enterprise_l and not isEmptyString(query_preset) then
   -- lua_utils: needed by db_query_presets and datatable_utils
   require "lua_utils"
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   local alert_entities = require "alert_entities"
   local db_query_presets = require "db_query_presets"
   local os_utils = require "os_utils"

   local preset = alert_entities[page] and db_query_presets.get_presets(
      os_utils.fixPath(dirs.installdir .. "/scripts/historical/alerts/" .. page)
   )[query_preset]

   if preset and preset.select and #preset.select.items > 0 then
      local datatable_utils = require "datatable_utils"
      columns_def = {}

      for _, item in ipairs(preset.select.items) do
         local i18n_label = item.name
         local column_def = nil

         -- Hide columns which are already rendered in other columns (e.g. cli_name -> cli_ip)
         if item.name == 'name' or
            item.name == 'cli_name' or
            item.name == 'srv_name' then
            goto continue
         end

         if item.flowfilter then
            column_def = datatable_utils.get_datatable_column_def_by_flowfilter(item.flowfilter)
            i18n_label = column_def.title_i18n
         else
            local def_builder = nil
            if item.value_type then
               def_builder = datatable_utils.datatable_column_def_builder_by_type[item.value_type]
            end
            if not def_builder then
               def_builder = datatable_utils.datatable_column_def_builder_by_type['default']
            end

            if i18n(item.name) then
               i18n_label = item.name
            elseif i18n("db_search." .. item.name) then
               i18n_label = "db_search." .. item.name
            elseif i18n("db_search.flowfilters." .. item.name) then
               i18n_label = "db_search.flowfilters." .. item.name
            end

            -- if the localized title is not available, set title to the label from the preset
            local title
            if i18n_label and isEmptyString(i18n(i18n_label)) then
               title = i18n_label
               i18n_label = nil
            end

            column_def = def_builder(item.name, i18n_label)

            if title then
               column_def.title = title
            end
         end

         columns_def[#columns_def + 1] = column_def

         ::continue::
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, {
   ifid = interface.getId(),
   is_admin = isAdministrator(),
   is_lightview = is_lightview,
   is_pro = (ntop.isPro and ntop.isPro()) or false,
   is_enterprise_m = is_enterprise_m,
   is_enterprise_l = is_enterprise_l,
   has_clickhouse = has_clickhouse,
   has_geoip = (ntop.hasGeoIP and ntop.hasGeoIP()) or false,
   traffic_extraction_available = traffic_extraction_available,
   -- Flow Details side card preference
   flow_details_card = ntop.getPref("ntopng.prefs.flow_details_card") ~= "0",
   columns_def = columns_def,
})
