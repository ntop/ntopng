--
-- (C) 2020-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local trace_alert_page = ntop.getCache("ntopng.trace.alerts_page")
local trace_stats = {}

require "ntop_utils"
require "lua_trace"

if not isEmptyString(trace_alert_page) then
    trace_stats = startProfiling("scripts/lua/alert_stats.lua")
end
require "lua_utils_get"

if not isEmptyString(trace_alert_page) then
    traceProfiling("lua_utils_get", trace_stats)
end

require "check_redis_prefs"

if not isEmptyString(trace_alert_page) then
    traceProfiling("check_redis_prefs", trace_stats)
end
local page_utils = require "page_utils"

if not isEmptyString(trace_alert_page) then
    traceProfiling("page_utils", trace_stats)
end
local json = require "dkjson"

if not isEmptyString(trace_alert_page) then
    traceProfiling("dkjson", trace_stats)
end
local template_utils = require "template_utils"

if not isEmptyString(trace_alert_page) then
    traceProfiling("template_utils", trace_stats)
end
local alert_entities = require "alert_entities"

if not isEmptyString(trace_alert_page) then
    traceProfiling("alert_entities", trace_stats)
end
local alert_store_utils = require "alert_store_utils"

if not isEmptyString(trace_alert_page) then
    traceProfiling("alert_store_utils", trace_stats)
end
local recording_utils = require "recording_utils"

if not isEmptyString(trace_alert_page) then
    traceProfiling("recording_utils", trace_stats)
end

local ifid = interface.getId()
local alert_store_instances = alert_store_utils.all_instances_factory()

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
local endpoint_list = "/lua/rest/v2/get/host/alert/list.lua"
local endpoint_ts = "/lua/rest/v2/get/host/alert/ts.lua"
local endpoint_delete = "/lua/rest/v2/delete/host/alerts.lua"
local endpoint_acknowledge = "/lua/rest/v2/acknowledge/host/alerts.lua"
local download_endpoint_list = endpoint_list
local interface_stats = interface.getStats()

-- ##################################################

-- Used to print badges next to navbar entries
local num_alerts_engaged = interface_stats["num_alerts_engaged"]
local num_alerts_engaged_by_entity = interface_stats["num_alerts_engaged_by_entity"]

-- Add system alerts to be displayed as badges in the interface page too
if interface.getId() ~= tonumber(getSystemInterfaceId()) then
    local system_interface_stats = ntop.getSystemAlertsStats()
    local num_system_alerts_engaged_by_entity = system_interface_stats["num_alerts_engaged_by_entity"]

    num_alerts_engaged = num_alerts_engaged + system_interface_stats["num_alerts_engaged"]

    for entity_id, num in pairs(num_system_alerts_engaged_by_entity) do
        if num_alerts_engaged_by_entity[entity_id] then
            num_alerts_engaged_by_entity[entity_id] = num_alerts_engaged_by_entity[entity_id] + num
        else
            num_alerts_engaged_by_entity[entity_id] = num
        end
    end
end

-- ##################################################

local pages = {{
    active = page == "all",
    page_name = "all",
    label = i18n("all"),
    endpoint_list = "/lua/rest/v2/get/all/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/all/alert/ts.lua",
    url = getPageUrl(base_url, {
        page = "all"
    }),
    badge_num = num_alerts_engaged
}, {
    active = page == "host",
    page_name = "host",
    label = i18n(alert_entities.host.i18n_label),
    endpoint_list = "/lua/rest/v2/get/host/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/host/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/host/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/host/alerts.lua",
    url = getPageUrl(base_url, {
        page = "host"
    }),
    hidden = is_system_interface or not alert_store_instances["host"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.host.entity_id)]
}, {
    active = page == "interface",
    page_name = "interface",
    label = i18n(alert_entities.interface.i18n_label),
    endpoint_list = "/lua/rest/v2/get/interface/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/interface/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/interface/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/interface/alerts.lua",
    url = getPageUrl(base_url, {
        page = "interface"
    }),
    hidden = not alert_store_instances["interface"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.interface.entity_id)]
}, {
    active = page == "network",
    page_name = "network",
    label = i18n(alert_entities.network.i18n_label),
    endpoint_list = "/lua/rest/v2/get/network/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/network/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/network/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/network/alerts.lua",
    url = getPageUrl(base_url, {
        page = "network"
    }),
    hidden = is_system_interface or not alert_store_instances["network"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.network.entity_id)]
}, {
    active = page == "snmp_device",
    page_name = "snmp_device",
    label = i18n(alert_entities.snmp_device.i18n_label),
    endpoint_list = "/lua/pro/rest/v2/get/snmp/device/alert/list.lua",
    endpoint_ts = "/lua/pro/rest/v2/get/snmp/device/alert/ts.lua",
    endpoint_delete = "/lua/pro/rest/v2/delete/snmp/device/alerts.lua",
    endpoint_acknowledge = "/lua/pro/rest/v2/acknowledge/snmp/device/alerts.lua",
    url = getPageUrl(base_url_historical_only, {
        page = "snmp_device"
    }),
    hidden = --[[ not is_system_interface or --]] not ntop.isPro() or
        not alert_store_instances["snmp_device"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.snmp_device.entity_id)]
}, {
    active = page == "flow",
    page_name = "flow",
    label = i18n(alert_entities.flow.i18n_label),
    endpoint_list = "/lua/rest/v2/get/flow/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/flow/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/flow/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/flow/alerts.lua",
    url = getPageUrl(base_url_historical_only, {
        page = "flow"
    }),
    hidden = is_system_interface or not alert_store_instances["flow"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.flow.entity_id)]
}, {
    active = page == "mac",
    page_name = "mac",
    label = i18n(alert_entities.mac.i18n_label),
    endpoint_list = "/lua/rest/v2/get/mac/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/mac/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/mac/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/mac/alerts.lua",
    url = getPageUrl(base_url_historical_only, {
        page = "mac"
    }),
    hidden = is_system_interface,
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.mac.entity_id)]
}, {
    active = page == "system",
    page_name = "system",
    label = i18n(alert_entities.system.i18n_label),
    endpoint_list = "/lua/rest/v2/get/system/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/system/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/system/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/system/alerts.lua",
    url = getPageUrl(base_url_historical_only, {
        page = "system"
    }),
    hidden = --[[ not is_system_interface or --]] not alert_store_instances["system"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.system.entity_id)]
}, {
    active = page == "am_host",
    page_name = "am_host",
    label = i18n(alert_entities.am_host.i18n_label),
    endpoint_list = "/lua/rest/v2/get/am_host/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/am_host/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/am_host/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/am_host/alerts.lua",
    url = getPageUrl(base_url, {
        page = "am_host"
    }),
    hidden = --[[ not is_system_interface or --]] not alert_store_instances["am"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.am_host.entity_id)]
}, {
    active = page == "user",
    page_name = "user",
    label = i18n(alert_entities.user.i18n_label),
    endpoint_list = "/lua/rest/v2/get/user/alert/list.lua",
    endpoint_ts = "/lua/rest/v2/get/user/alert/ts.lua",
    endpoint_delete = "/lua/rest/v2/delete/user/alerts.lua",
    endpoint_acknowledge = "/lua/rest/v2/acknowledge/user/alerts.lua",
    url = getPageUrl(base_url_historical_only, {
        page = "user"
    }),
    hidden = --[[ not is_system_interface or --]] not alert_store_instances["user"]:has_alerts(),
    badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.user.entity_id)]
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

if not isEmptyString(trace_alert_page) then
    traceProfiling("page", trace_stats)
end

-- ##################################################

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.detected_alerts)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

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

if not isEmptyString(trace_alert_page) then
    traceProfiling("page", trace_stats)
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


if not isEmptyString(trace_alert_page) then
    traceProfiling("context", trace_stats)
end

local json_context = json.encode(context)
template_utils.render("pages/vue_page.template", {
    vue_page_name = "PageAlertStats",
    page_context = json_context
})

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
