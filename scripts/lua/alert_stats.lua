--
-- (C) 2020-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local trace_alert_page = ntop.getCache("ntopng.trace.alerts_page")
local trace_stats = {}

require "ntop_utils"
require "lua_utils_get"
require "lua_utils_gui"
require "check_redis_prefs"
local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local alert_entities = require "alert_entities"
local recording_utils = require "recording_utils"

local ifid = interface.getId()

-- select the default page
local page = _GET["page"]
local status = _GET["status"]

-- Safety check
if not page or not alert_entities[page] then
    page = 'all'
end

-- ##################################################

sendHTTPContentTypeHeader('text/html')

local CHART_NAME = "alert-timeseries"
local is_system_interface = page_utils.is_system_view()
local base_params = table.clone(_GET)
base_params["page"] = nil
base_params["alert_id"] = nil
local base_url = getPageUrl(ntop.getHttpPrefix() .. "/lua/alert_stats.lua", base_params)

base_params["status"] = "historical"
local base_url_historical_only = getPageUrl(ntop.getHttpPrefix() .. "/lua/alert_stats.lua", base_params)
local master_ifid = interface.getMasterInterfaceId()
local traffic_extraction_available = recording_utils.isActive(master_ifid) or
                                         recording_utils.isExtractionActive(master_ifid)
local endpoint_cards = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/" .. page .. "/alert/top.lua"
local alert_details_url = ntop.getHttpPrefix() .. "/lua/alert_details.lua"
local endpoint_list = "/lua/rest/v2/get/PAGE/alert/list.lua"
local download_endpoint_list = endpoint_list

-- ##################################################

local pages = {{
    active = page == "all",
    page_name = "all",
    label = i18n("all"),
    url = getPageUrl(base_url, {
        page = "all"
    }),
}, {
    active = page == "host",
    page_name = "host",
    label = i18n(alert_entities.host.i18n_label),
    url = getPageUrl(base_url, {
        page = "host"
    }),
    hidden = is_system_interface,
}, {
    active = page == "interface",
    page_name = "interface",
    label = i18n(alert_entities.interface.i18n_label),
    url = getPageUrl(base_url, {
        page = "interface"
    }),
}, {
    active = page == "network",
    page_name = "network",
    label = i18n(alert_entities.network.i18n_label),
    url = getPageUrl(base_url, {
        page = "network"
    }),
    hidden = is_system_interface,
}, {
    active = page == "snmp_device",
    page_name = "snmp_device",
    label = i18n(alert_entities.snmp_device.i18n_label),
    url = getPageUrl(base_url_historical_only, {
        page = "snmp_device"
    }),
    hidden = not ntop.isPro(),
}, {
    active = page == "flow",
    page_name = "flow",
    label = i18n(alert_entities.flow.i18n_label),
    url = getPageUrl(base_url_historical_only, {
        page = "flow"
    }),
    hidden = is_system_interface,
}, {
    active = page == "mac",
    page_name = "mac",
    label = i18n(alert_entities.mac.i18n_label),
    url = getPageUrl(base_url_historical_only, {
        page = "mac"
    }),
    hidden = is_system_interface,
}, {
    active = page == "system",
    page_name = "system",
    label = i18n(alert_entities.system.i18n_label),
    url = getPageUrl(base_url_historical_only, {
        page = "system"
    }),
}, {
    active = page == "am_host",
    page_name = "am_host",
    label = i18n(alert_entities.am_host.i18n_label),
    url = getPageUrl(base_url, {
        page = "am_host"
    }),
}, {
    active = page == "user",
    page_name = "user",
    label = i18n(alert_entities.user.i18n_label),
    url = getPageUrl(base_url_historical_only, {
        page = "user"
    }),
}}

-- Iterate back to front to remove items if necessary
for i = #pages, 1, -1 do
    local cur_page = pages[i]

    if cur_page.hidden then
        table.remove(pages, i)
    end
end

if endpoint_list then
    endpoint_list = ntop.getHttpPrefix() .. endpoint_list
end

-- ##################################################

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.detected_alerts)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ##################################################

-- Query Presets (Custom Queries)

local dt_columns_def

local query_preset = _GET["query_preset"] -- Example: &query_preset=contacts

if ntop.isEnterpriseL() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path 
   local db_query_presets = require "db_query_presets"
   local os_utils = require "os_utils"
   local datatable_utils = require "datatable_utils"

   local query_presets = db_query_presets.get_presets(
      os_utils.fixPath(dirs.installdir .. "/scripts/historical/alerts/" .. page)
   )

   if isEmptyString(query_preset) or not query_presets[query_preset] then
      query_preset = ""
   else
      local preset = query_presets[query_preset]

      -- Table columns
      if preset.select and #preset.select.items > 0 then

         -- New columns definition (used to build a JSON definition)
         dt_columns_def = {}

         for _, item in ipairs(preset.select.items) do
            local i18n_label = item.name
            local column_def = nil

            -- Hide columns which are already rendered in other columns (e.g. cli_name -> cli_ip)
            if item.name == 'name' or
               item.name == 'cli_name' or
               item.name == 'srv_name' then
               goto continue
            end

            if item.tag then
               column_def = datatable_utils.get_datatable_column_def_by_tag(item.tag)
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
               elseif i18n("db_search.tags." .. item.name) then
                  i18n_label = "db_search.tags." .. item.name
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

            dt_columns_def[#dt_columns_def + 1] = column_def

            ::continue::
         end
      end
   end
end

-- ##################################################

if traffic_extraction_available then
    local ui_utils = require "ui_utils"
    -- PCAP modal for alert traffic extraction
    ui_utils.draw_pcap_download_dialog(master_ifid)
end

if page == 'snmp_device' then
    endpoint_cards = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/snmp/device/alert/top.lua"
end

-- ClickHouse enabled, redirect to the pro details page
if ((page == 'host') or (page == 'flow') or (page == 'am_host')) and ntop.isEnterpriseM() and hasClickHouseSupport() then
    alert_details_url = ntop.getHttpPrefix() .. "/lua/pro/db_flow_details.lua"
end

-- If the status is not explicitly set, it is chosen between (engaged when there are engaged alerts) or historical when
-- no engaged alert is currently active
if not status then
    -- Default to historical
    status = "historical"
end

-- ##################################################

local context = {
    ifid = ifid,
    is_ntop_enterprise_m = ntop.isEnterpriseM(),
    is_ntop_enterprise_l = ntop.isEnterpriseL(),
    show_chart = true,
    show_cards = (status ~= "engaged") and ntop.isPro(),
    endpoint_cards = endpoint_cards,
    show_permalink = (page ~= 'all'),
    show_download = (page ~= 'all'),
    show_acknowledge_all = (page ~= 'all') and (status == "historical"),
    show_delete_all = (page ~= 'all') and (status ~= "engaged"),
    show_actions = (page ~= 'all'),
    columns_def = dt_columns_def, -- custom columns definition (custom queries)
    download = {
        endpoint = download_endpoint_list
    },
    actions = {
        show_settings = (page ~= 'system') and isAdministrator(),
        show_flows = (page == 'host'),
        show_historical = ((page == 'host') or (page == 'flow') or (page == 'am_host')) and ntop.isEnterpriseM() and
            hasClickHouseSupport(),
        show_pcap_download = traffic_extraction_available and page == 'flow',
        show_disable = ((page == 'host') or (page == 'flow')) and isAdministrator() and ntop.isEnterpriseM(),
        show_acknowledge = (page ~= 'all') and (status == "historical") and isAdministrator(),
        show_delete = (page ~= 'all') and (status ~= "engaged") and isAdministrator(),
        show_info = (page == 'flow'),
        show_snmp_info = (page == 'snmp_device')
    },
    chart = {
        name = CHART_NAME
    },
    alert_details_url = alert_details_url,
    navbar = page_utils.get_new_navbar_context(i18n("alerts_dashboard.alerts"), ntop.getHttpPrefix() .. "/lua/alert_stats.lua?", pages),
    csrf = ntop.getRandomCSRFValue(),
    is_va = _GET["is_va"] or false
}

local json_context = json.encode(context)
template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageAlertStats",
    page_context = json_context
})

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
