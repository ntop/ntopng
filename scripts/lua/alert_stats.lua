--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local ui_utils = require "ui_utils"
local alert_consts = require "alert_consts"
local json = require "dkjson"
local template_utils = require "template_utils"
local widget_gui_utils = require "widget_gui_utils"
local tag_utils = require "tag_utils"
local alert_entities = require "alert_entities"
local Datasource = widget_gui_utils.datasource
local alert_store_utils = require "alert_store_utils"
local alert_utils = require "alert_utils"
local alert_store = require "alert_store"
local recording_utils = require "recording_utils"
local datatable_utils = require "datatable_utils"

local ifid = interface.getId()
local alert_store_instances = alert_store_utils.all_instances_factory()

local alert_score_cached = "ntopng.alert.score.ifid_" .. ifid .. ""
local refresh_rate = ntop.getPref("ntopng.prefs.alert_page_refresh_rate")

-- Alert page refresh rate
if (ntop.getPref("ntopng.prefs.alert_page_refresh_rate_enabled") == '1') 
   and refresh_rate 
   and not isEmptyString(refresh_rate) then
   -- The js function that refresh periodically the page needs the time in microseconds
   refresh_rate = tonumber(refresh_rate) * 1000
   -- Refresh rate equals to 0, remove refresh rate
   if refresh_rate == 0 then
      refresh_rate = nil
   end
else
   refresh_rate = nil
end

local user = "no_user"

if (_SESSION) and (_SESSION["user"]) then
   user = _SESSION["user"]
end

local ALERT_SORTING_ORDER = "ntopng.cache.alert." .. ifid .. "." .. user .. ".sort_order."
local ALERT_SORTING_COLUMN = "ntopng.cache.alert." .. ifid .. "." .. user .. ".sort_column."

local CHART_NAME = "alert-timeseries"

-- select the default page
local page = _GET["page"] or 'all'
local status = _GET["status"]

local interface_stats = interface.getStats()

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

local num_alerts_engaged_cur_entity = 0
if alert_entities[page] then
   local entity_id = tostring(alert_entities[page].entity_id)
   num_alerts_engaged_cur_entity = num_alerts_engaged_by_entity[entity_id] or 0
elseif page == 'all' and num_alerts_engaged then
   num_alerts_engaged_cur_entity = num_alerts_engaged
end

-- If the status is not explicitly set, it is chosen between (engaged when there are engaged alerts) or historical when
-- no engaged alert is currently active
if not status then
   -- Default to historical
   status = "historical"

   -- Always show the historical page to avoid flapping when reloading the alerts page
   -- which is confusing for the user. This also prevents syncronization issues between
   -- lua and js (as they do not currently share the 'status').
   --[[
   if page ~= "all" then
     -- If there alert alerts engaged for the selected entity, go to the engaged tab
     if alert_entities[page] and num_alerts_engaged_by_entity[tostring(alert_entities[page].entity_id)] then
       status = "engaged"
     end
   else
     -- For the 'all' page, the tab 'engaged' is selected if there is at least one entity with engaged alerts
     for _, n in pairs(num_alerts_engaged_by_entity) do
       if n > 0 then
          status = "engaged"
          break
       end
     end
   end
   --]]
end

-- Check the earliest alert available
local alert_store_instance
if alert_entities[page] and alert_store_instances[alert_entities[page].alert_store_name] then
   alert_store_instance = alert_store_instances[alert_entities[page].alert_store_name]
elseif page == "all" then
   alert_store_instance = require "all_alert_store".new()
end

local earliest_available_epoch = alert_store_instance:get_earliest_available_epoch(status)

local time = os.time()

-- initial epoch_begin is set as now - 30 minutes for historical, or as 1 week for engaged
local epoch_begin = _GET["epoch_begin"] or time - (1800) -- 30 minutes
local epoch_end = _GET["epoch_end"] or time
local time_range_query = "epoch_begin="..epoch_begin.."&epoch_end="..epoch_end

--------------------------------------------------------------

local alert_id = _GET["alert_id"]
local severity = _GET["severity"]
local score = _GET["score"]
local ip_version = _GET["ip_version"]
local host_ip = _GET["ip"]
local host_name = _GET["name"]
local cli_ip = _GET["cli_ip"]
local srv_ip = _GET["srv_ip"]
local cli_name = _GET["cli_name"]
local srv_name = _GET["srv_name"]
local cli_port = _GET["cli_port"]
local srv_port = _GET["srv_port"]
local l7_proto = _GET["l7_proto"]
local network_name = _GET["network_name"]
local role = _GET["role"]
local role_cli_srv = _GET["role_cli_srv"]
local l7_error_id = _GET["l7_error_id"]
local community_id = _GET["community_id"]
local ja3_client = _GET["ja3_client"]
local ja3_server = _GET["ja3_server"]
local confidence = _GET["confidence"]
local traffic_direction = _GET["traffic_direction"]
local subtype = _GET["subtype"]
local vlan_id = _GET["vlan_id"]
local alert_domain = _GET["alert_domain"]

--------------------------------------------------------------

-- Remember the score filter (see also alert_store.lua)
if isEmptyString(score) then
   score = ntop.getCache(alert_score_cached)
   _GET["score"] = score
end

sendHTTPContentTypeHeader('text/html')

local is_system_interface = page_utils.is_system_view()

-- default endpoints (host)
local endpoint_list = "/lua/rest/v2/get/host/alert/list.lua"
local endpoint_ts = "/lua/rest/v2/get/host/alert/ts.lua"
local endpoint_delete = "/lua/rest/v2/delete/host/alerts.lua"
local endpoint_acknowledge = "/lua/rest/v2/acknowledge/host/alerts.lua"

-- Preserve page params when switching between tabs
local base_params = table.clone(_GET)
base_params["page"] = nil
base_params["alert_id"] = nil
local base_url = getPageUrl(ntop.getHttpPrefix().."/lua/alert_stats.lua", base_params)

base_params["status"] = "historical"
local base_url_historical_only = getPageUrl(ntop.getHttpPrefix().."/lua/alert_stats.lua", base_params)

local pages = {
   {
      active = page == "all",
      page_name = "all",
      label = i18n("all"),
      endpoint_list = "/lua/rest/v2/get/all/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/all/alert/ts.lua",
      url = getPageUrl(base_url, {page = "all"}),
      badge_num = num_alerts_engaged,
   },
   {
      active = page == "host",
      page_name = "host",
      label = i18n(alert_entities.host.i18n_label),
      endpoint_list = "/lua/rest/v2/get/host/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/host/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/host/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/host/alerts.lua",
      url = getPageUrl(base_url, {page = "host"}),
      hidden = is_system_interface or not alert_store_instances["host"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.host.entity_id)]
   },
   {
      active = page == "interface",
      page_name = "interface",
      label = i18n(alert_entities.interface.i18n_label),
      endpoint_list = "/lua/rest/v2/get/interface/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/interface/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/interface/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/interface/alerts.lua",
      url = getPageUrl(base_url, {page = "interface"}),
      hidden = not alert_store_instances["interface"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.interface.entity_id)]
   },
   {
      active = page == "network",
      page_name = "network",
      label = i18n(alert_entities.network.i18n_label),
      endpoint_list = "/lua/rest/v2/get/network/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/network/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/network/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/network/alerts.lua",
      url = getPageUrl(base_url, {page = "network"}),
      hidden = is_system_interface or not alert_store_instances["network"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.network.entity_id)]
   },
   {
      active = page == "snmp_device",
      page_name = "snmp_device",
      label = i18n(alert_entities.snmp_device.i18n_label),
      endpoint_list = "/lua/pro/rest/v2/get/snmp/device/alert/list.lua",
      endpoint_ts = "/lua/pro/rest/v2/get/snmp/device/alert/ts.lua",
      endpoint_delete = "/lua/pro/rest/v2/delete/snmp/device/alerts.lua",
      endpoint_acknowledge = "/lua/pro/rest/v2/acknowledge/snmp/device/alerts.lua",
      url = getPageUrl(base_url_historical_only, {page = "snmp_device"}),
      hidden = --[[ not is_system_interface or --]] not ntop.isPro() or not alert_store_instances["snmp_device"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.snmp_device.entity_id)]
   },
   {
      active = page == "flow",
      page_name = "flow",
      label = i18n(alert_entities.flow.i18n_label),
      endpoint_list = "/lua/rest/v2/get/flow/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/flow/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/flow/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/flow/alerts.lua",
      url = getPageUrl(base_url_historical_only, {page = "flow"}),
      hidden = is_system_interface or not alert_store_instances["flow"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.flow.entity_id)]
   },
   {
      active = page == "mac",
      page_name = "mac",
      label = i18n(alert_entities.mac.i18n_label),
      endpoint_list = "/lua/rest/v2/get/mac/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/mac/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/mac/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/mac/alerts.lua",
      url = getPageUrl(base_url_historical_only, {page = "mac"}),
      hidden = is_system_interface,
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.mac.entity_id)]
   },
   {
      active = page == "system",
      page_name = "system",
      label = i18n(alert_entities.system.i18n_label),
      endpoint_list = "/lua/rest/v2/get/system/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/system/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/system/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/system/alerts.lua",
      url = getPageUrl(base_url_historical_only, {page = "system"}),
      hidden = --[[ not is_system_interface or --]] not alert_store_instances["system"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.system.entity_id)]
   },
   {
      active = page == "am_host",
      page_name = "am_host",
      label = i18n(alert_entities.am_host.i18n_label),
      endpoint_list = "/lua/rest/v2/get/am_host/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/am_host/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/am_host/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/am_host/alerts.lua",
      url = getPageUrl(base_url, {page = "am_host"}),
      hidden = --[[ not is_system_interface or --]] not alert_store_instances["am"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.am_host.entity_id)]
   },
   {
      active = page == "user",
      page_name = "user",
      label = i18n(alert_entities.user.i18n_label),
      endpoint_list = "/lua/rest/v2/get/user/alert/list.lua",
      endpoint_ts = "/lua/rest/v2/get/user/alert/ts.lua",
      endpoint_delete = "/lua/rest/v2/delete/user/alerts.lua",
      endpoint_acknowledge = "/lua/rest/v2/acknowledge/user/alerts.lua",
      url = getPageUrl(base_url_historical_only, {page = "user"}),
      hidden = --[[ not is_system_interface or --]] not alert_store_instances["user"]:has_alerts(),
      badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.user.entity_id)]
   }
}

-- Iterate back to front to remove items if necessary
for i = #pages, 1, -1 do
   local cur_page = pages[i]

   if cur_page.hidden then
     table.remove(pages, i)
   elseif cur_page.page_name == page then
     endpoint_list = cur_page.endpoint_list
     endpoint_ts = cur_page.endpoint_ts
     endpoint_delete = cur_page.endpoint_delete
     endpoint_acknowledge = cur_page.endpoint_acknowledge
   end
end

if endpoint_list then
   endpoint_list = ntop.getHttpPrefix() .. endpoint_list
end

local prefs = ntop.getPrefs()
local download_endpoint_list = endpoint_list
local download_file_name = 'alerts-' .. os.time()

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?"

-- page_utils.print_navbar(i18n("alerts_dashboard.alerts"), url, pages)

-- widget_gui_utils.register_timeseries_area_chart(CHART_NAME, 0, {
--    Datasource(endpoint_ts, {
--        ifid = ifid,
--        vlan_id = vlan_id,
--        epoch_begin = epoch_begin,
--        epoch_end = epoch_end,
--        status = status,
--        alert_id = alert_id,
--        severity = severity,
--       score = score,
--        ip_version = ip_version,
--        ip = host_ip,
--        name = host_name,
--        cli_ip = cli_ip,
--        srv_ip = srv_ip,
--        cli_name = cli_name,
--        srv_name = srv_name,
--        cli_port = cli_port,
--        srv_port = srv_port,
--        l7_proto = l7_proto,
--        network_name = network_name,
--        role = role,
--       role_cli_srv = role_cli_srv,
--       subtype = subtype,
--    })
-- })

-- ######################################

-- Set visible columns by default (if not set by the user) 
if page == 'flow' and not datatable_utils.has_saved_column_preferences(page .. "-alerts-table") then
   local hidden_columns = ''
   local js_columns_default_hidden = {
      { 
         name = tstamp,
         default_hidden = false,
      }, {
         name = score,
         default_hidden = false,
      }, {
         name = l7_proto,
         default_hidden = false,
      }, {
         name = alert,
         default_hidden = false,
      }, {
         name = flow,
         default_hidden = false,
      }, {
         name = count,
         default_hidden = false,
      }, {
         name = description,
         default_hidden = false,
      }, {
         name = community_id,
         default_hidden = true,
      }, {
         name = info,
         default_hidden = false,
      }, {
         name = cli_host_pool_id,
         default_hidden = true,
      }, {
         name = srv_host_pool_id,
         default_hidden = true,
      }, {
         name = cli_network,
         default_hidden = true,
      }, {
         name = srv_network,
         default_hidden = true,
      }, {
         name = probe_ip,
         default_hidden = true,
      }
   }
   for index, data in pairs(js_columns_default_hidden) do
      if data.default_hidden then
         hidden_columns = hidden_columns .. (index - 1) .. ","
      end
   end

   if not isEmptyString(hidden_columns) then
      hidden_columns = hidden_columns:sub(1, -2)
      datatable_utils.save_column_preferences(page .. "-alerts-table", hidden_columns)
   end
end

-- ######################################

local modals = {
   ["delete_alert_dialog"] = template_utils.gen("modal_confirm_dialog_form.template", {
       dialog = {
           id      = "delete_alert_dialog",
           title   = i18n("show_alerts.delete_alert"),
           message = i18n("show_alerts.confirm_delete_alert") .. '?',
           confirm = i18n("delete"),
           confirm_button = "btn-danger",
           custom_alert_class = "alert alert-danger",
           no_confirm_id = true
       }
   }),
   ["acknowledge_alert_dialog"] = template_utils.gen("pages/modals/alerts/acknowledge_alert.template", {
       dialog = {
           id      = "acknowledge_alert_dialog",
           title   = i18n("show_alerts.acknowledge_alert"),
           message = i18n("show_alerts.confirm_acknowledge_alert"),
           confirm = i18n("acknowledge"),
           confirm_button = "btn-primary",
           custom_alert_class = "alert alert-warning",
           no_confirm_id = true
       }
   }),
   -- ["alerts_filter_dialog"] = template_utils.gen("pages/modals/modal_alerts_filter_dialog.html", {
   --     dialog = {
   --         id = "alerts_filter_dialog",
   --         title = i18n("show_alerts.filter_alert"),
   --         message      = i18n("show_alerts.confirm_filter_alert"),
   --         delete_message = i18n("show_alerts.confirm_delete_filtered_alerts"),
   --         delete_alerts = i18n("delete_disabled_alerts"),
   --         alert_filter = "default_filter",
   --         confirm = i18n("filter"),
   --         confirm_button = "btn-warning",
   --         custom_alert_class = "alert alert-danger",
   --         entity = page
   --     }
   -- }),
   ["release_single_alert"] = template_utils.gen("modal_confirm_dialog_form.template", {
       dialog = {
           id      = "release_single_alert",
           title   = i18n("show_alerts.release_alert"),
           message = i18n("show_alerts.confirm_release_alert"),
           confirm = i18n("show_alerts.release_alert_action"),
           confirm_button = "btn-primary",
           custom_alert_class = "alert alert-primary",
           no_confirm_id = true
       }
   }),
   ["dt-delete-modal"] = template_utils.gen("pages/modals/alerts/delete_alerts.template", {
          dialog={
           id      = "dt-delete-modal",
           title   = i18n("delete_alerts"),
           label   = "",
           message = i18n("show_alerts.confirm_delete_alerts"),
           cancel  = i18n("cancel"),
              apply   = i18n("delete")
          }
   }),
   ["dt-acknowledge-modal"] = template_utils.gen("pages/modals/alerts/acknowledge_alerts.template",{
          dialog={
           id      = "dt-acknowledge-modal",
           title   = i18n("acknowledge_alerts"),
           label   = "",
           message = i18n("show_alerts.confirm_acknowledge_alerts"),
           cancel  = i18n("cancel"),
          apply   = i18n("acknowledge")
          }
   }),
   ["external-link"] = template_utils.gen("pages/modals/alerts/redirect_modal.template", {
       dialog={
           id      = "external-link",
           title   = i18n("external_link"),
           message = i18n("show_alerts.confirm_external_link"),
           message2= i18n("are_you_sure"),
           cancel  = i18n("cancel"),
           apply   = i18n("redirect")
       }
   })

}

local operators_by_filter = {
   alert_id = {'eq','neq'},
   severity = {'eq','lte','gte','neq'},
   score = {'eq','lte','gte'},
   ip_version = {'eq','neq'},
   ip = {'eq','neq'},
   port = {'eq','neq'},
   l7_proto  = {'eq','neq'},
   role = {'eq'},
   role_cli_srv = {'eq'},
   l7_error_id = {'eq','neq'},
   community_id = {'eq','neq', 'in', 'nin'},
   ja3_client = {'eq','neq','in','nin'},
   ja3_server = {'eq','neq','in','nin'},
   alert_domain = {'eq','neq','in','nin'},
   confidence = {'eq','neq'},
   traffic_direction = {'eq','neq'},
   text = {'eq','neq'},
   hostname = {'eq','neq', 'in', 'nin'},
}

local defined_tags = {
   ["host"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,

      ip_version = operators_by_filter.ip_version,
      ip = operators_by_filter.ip,
      name = operators_by_filter.hostname,
      role = operators_by_filter.role,
      role_cli_srv = operators_by_filter.role_cli_srv,
   },
   ["mac"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,
   },
   ["snmp_device"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,
   },
   ["flow"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,

      l7_proto  = operators_by_filter.l7_proto,
      ip_version = operators_by_filter.ip_version,
      ip = operators_by_filter.ip,
      name = operators_by_filter.hostname,
      cli_ip = operators_by_filter.ip,
      srv_ip = operators_by_filter.ip,
      cli_name = operators_by_filter.hostname,
      srv_name = operators_by_filter.hostname,
      cli_port = operators_by_filter.port,
      srv_port = operators_by_filter.port,
      role = operators_by_filter.role,
      l7_error_id = operators_by_filter.l7_error_id,
      community_id = operators_by_filter.community_id,
      ja3_client = operators_by_filter.ja3_client,
      ja3_server = operators_by_filter.ja3_server,
      traffic_direction = operators_by_filter.traffic_direction,
      confidence = operators_by_filter.confidence,
      alert_domain = operators_by_filter.alert_domain
   },
   ["system"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,
   },
   ["am_host"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,
   },
   ["interface"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,

      subtype = operators_by_filter.text,
   },
   ["user"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,
   },
   ["network"] = {
      alert_id = operators_by_filter.alert_id,
      severity = operators_by_filter.severity,
      score = operators_by_filter.score,

      network_name = operators_by_filter.text,
   }
}

local initial_tags = {}

if page ~= "all" then
   tag_utils.formatters.l7_proto = function(proto) return interface.getnDPIProtoName(tonumber(proto)) end
   tag_utils.formatters.alert_id = function(alert_id) return (alert_consts.alertTypeLabel(tonumber(alert_id), true, alert_entities[page].entity_id) or alert_id) end
end

for tag_key, operators in pairs(defined_tags[page] or {}) do
   tag_utils.add_tag_if_valid(initial_tags, tag_key, operators, 'db_search.tags')
end

local base_url = build_query_url({'status', 'page', 'epoch_begin', 'epoch_end'}) 

local extra_range_buttons = [[
   <div class='d-flex align-items-center me-2'>
       <div class="btn-group" id="statusSwitch" role="group">
           <a href=']] .. base_url .. [[&]]..time_range_query .. [[&status=historical&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "historical", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.past") .. [[</a>
           <a href=']] .. base_url .. [[&]]..time_range_query .. [[&status=acknowledged&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "acknowledged", "btn-primary active", "btn-secondary") ..[[" title=']].. i18n("show_alerts.acknowledged") ..[['>]] .. i18n("show_alerts.short_ack") .. [[</a>
           <a href=']] .. base_url .. [[&]]..time_range_query .. [[&status=engaged&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "engaged", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.engaged") .. ternary(num_alerts_engaged_cur_entity > 0, string.format('<span class="badge rounded-pill bg-dark" style="position: absolute; float: right; margin-bottom: -10px;">%u</span>', num_alerts_engaged_cur_entity), "") .. [[</a>
       </div>
   </div>
]]

local available_filter_types = {}
local all_alert_types = {}
local extra_tags_buttons = ""

if page ~= "all" then
   extra_tags_buttons = [[
   <button class="btn btn-link" aria-controls="]]..page..[[-alerts-table" type="button" id="btn-add-alert-filter" onclick="pageHandle.filterModalShow()"><span><i class="fas fa-plus" data-original-title="" title="]]..i18n("datatable.add_filter")..[["></i></span>
   </button>
   ]]

   if alert_store_instances[alert_entities[page].alert_store_name] then
     local alert_store_instance = alert_store_instances[alert_entities[page].alert_store_name]
     available_filter_types = alert_store_instance:get_available_filters()
     all_alert_types = alert_consts.getAlertTypesInfo(alert_entities[page].entity_id)
   end
end

ALERT_SORTING_ORDER = ALERT_SORTING_ORDER .. page
ALERT_SORTING_COLUMN = ALERT_SORTING_COLUMN .. page

local cached_sorting = ntop.getCache(ALERT_SORTING_ORDER)
local cached_column = ntop.getCache(ALERT_SORTING_COLUMN)

if isEmptyString(cached_sorting) then
   cached_sorting = "desc"
end

if isEmptyString(cached_column) then
   cached_column = "0"
end

local checkbox_checked = ""

if refresh_rate and refresh_rate > 0 then
   checkbox_checked = "fa-spin"
end

--------------------------------------------------------------

-- PCAP modal for alert traffic extraction
local master_ifid = interface.getMasterInterfaceId()
local traffic_extraction_available = recording_utils.isActive(master_ifid) or recording_utils.isExtractionActive(master_ifid)

if traffic_extraction_available then 
   ui_utils.draw_pcap_download_dialog(master_ifid)
end

--------------------------------------------------------------

local filters_context = {
   alert_utils = alert_utils,
   alert_consts = alert_consts,
   available_types = available_filter_types,
   severities = alert_consts.get_printable_severities(),
   alert_types = all_alert_types,
   l7_protocols = interface.getnDPIProtocols(),
   operators_by_filter = operators_by_filter,
   tag_operators = tag_utils.tag_operators,
   confidence_list = tag_utils.confidence,
   traffic_direction_list = tag_utils.traffic_direction
}

--template_utils.render("pages/modals/alerts/filters/add.template", filters_context)

--------------------------------------------------------------

local endpoint_cards = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/" .. page .. "/alert/top.lua"

if page == 'snmp_device' then
  endpoint_cards = ntop.getHttpPrefix() .. "/lua/pro/rest/v2/get/snmp/device/alert/top.lua"
end

local alert_details_url = ntop.getHttpPrefix().."/lua/alert_details.lua"

-- ClickHouse enabled, redirect to the pro details page
if ((page == 'host') or (page == 'flow')) and 
    ntop.isEnterpriseM() and 
    hasClickHouseSupport() then
  alert_details_url = ntop.getHttpPrefix().."/lua/pro/db_flow_details.lua"
end

local datasource_data = {
   ifid = ifid,
   epoch_begin = epoch_begin,
   epoch_end = epoch_end,
   status = status,
   alert_id = alert_id,
   severity = severity,
   score = score,
   ip_version = ip_version,
   ip = host_ip,
   name = host_name,
   cli_ip = cli_ip,
   srv_ip = srv_ip,
   cli_name = cli_name,
   srv_name = srv_name,
   cli_port = cli_port,
   srv_port = srv_port,
   l7_proto = l7_proto,
   network_name = network_name,
   role = role,
   role_cli_srv = role_cli_srv,
   l7_error_id = l7_error_id,
   community_id = community_id,
   ja3_client = ja3_client,
   ja3_server = ja3_server,
   alert_domain = alert_domain,
   confidence = confidence,
   traffic_direction = traffic_direction,
   subtype = subtype,
   page = page,
}

local datasource = Datasource(endpoint_list, datasource_data)

local datatable = {
   name = page .. "-alerts-table",
   datasource = datasource,
   initialLength = getDefaultTableSize(),
   pagination = 'full_numbers',
   show_admin_controls = isAdministrator(),
   columns_header = template_utils.gen(string.format("pages/alerts/families/%s/table.template", page), {}),
   columns_js = template_utils.gen(string.format("pages/alerts/families/%s/table.js.template", page), {}),
   order_name = cached_column,
   order_sorting = cached_sorting,
   modals = modals,
   download = {
      endpoint = download_endpoint_list,
      filename = "download_file_name.csv",
      format = "csv",
      i18n = i18n('show_alerts.download_alerts'),
   },
   endpoint_delete = endpoint_delete,
   endpoint_acknowledge = endpoint_acknowledge,
   refresh_rate = refresh_rate,
   actions = {
       disable = (page ~= "host" and page ~= "flow")
   },
}

local notes = {}

table.insert(notes, i18n("show_alerts.alerts_info"))

if(status == "engaged") then
   table.insert(notes, i18n("show_alerts.engaged_notes"))
end

local context_2 = {
   ifid = ifid,
   opsep = tag_utils.SEPARATOR,
   isPro = ntop.isPro(),
   is_ntop_enterprise_m = ntop.isEnterpriseM(),
   notes = notes,
   show_chart = true,
   show_cards = (status ~= "engaged") and ntop.isPro(),
   endpoint_cards = endpoint_cards,
   -- buttons
   show_permalink = (page ~= 'all'),
   show_download = (page ~= 'all'),
   show_acknowledge_all =  (page ~= 'all') and (status == "historical"),
   show_delete_all = (page ~= 'all') and (status ~= "engaged"),
   show_actions = (page ~= 'all'),
   actions = {
       show_settings = (page ~= 'system') and isAdministrator(),
       show_flows = (page == 'host'),
       show_historical = ((page == 'host') or (page == 'flow')) and ntop.isEnterpriseM() and hasClickHouseSupport(),
       show_pcap_download = traffic_extraction_available and page == 'flow',
       show_disable = ((page == 'host') or (page == 'flow')) and isAdministrator() and ntop.isEnterpriseM(),
       show_acknowledge = (page ~= 'all') and (status == "historical") and isAdministrator(),
       show_delete = (page ~= 'all') and (status ~= "engaged") and isAdministrator(),
       show_info = (page == 'flow'),
       show_snmp_info = (page == 'snmp_device')
   },

   show_tot_records = true,
   range_picker = {
       ifid = ifid,
       default = status ~= "engaged" and "30min" or "1week",
       earliest_available_epoch = earliest_available_epoch,
       epoch_begin = epoch_begin,
       epoch_end = epoch_end,
       datasource_params = datasource.params,
       refresh_enabled = checkbox_checked,
       opsep = tag_utils.SEPARATOR,
       dont_refresh_full_page = true,
       show_auto_refresh = (page ~= 'all'),
       tags = {
           enabled = (page ~= 'all'),
           tag_operators = tag_utils.tag_operators,
           view_only = true,
           defined_tags = defined_tags[page],
           values = initial_tags,
           i18n = {
               auto_refresh_descr = i18n("auto_refresh_descr"),
               enable_auto_refresh = auto_refresh_text,
               alert_id = i18n("db_search.tags.alert_id"),
               severity = i18n("db_search.tags.severity"),
               score = i18n("db_search.tags.score"),
               l7_proto = i18n("db_search.tags.l7proto"),
               cli_ip = i18n("db_search.tags.cli_ip"),
               srv_ip = i18n("db_search.tags.srv_ip"),
               cli_name = i18n("db_search.tags.cli_name"),
               srv_name = i18n("db_search.tags.srv_name"),
               cli_port = i18n("db_search.tags.cli_port"),
               srv_port = i18n("db_search.tags.srv_port"),
               ip_version = i18n("db_search.tags.ip_version"),
               ip = i18n("db_search.tags.ip"),
               name = i18n("db_search.tags.name"),
               network_name = i18n("db_search.tags.network_name"),
               subtype = i18n("alerts_dashboard.element"),
               role = i18n("db_search.tags.role"),
               role_cli_srv = i18n("db_search.tags.role_cli_srv"),
               l7_error_id = i18n("db_search.tags.error_code"),
               community_id = i18n("db_search.tags.community_id"),
               confidence = i18n("db_search.tags.confidence"),
               traffic_direction = i18n("db_search.tags.traffic_direction"),
          }
       },
       presets = {
           five_mins = false,
           month = false,
           year = false
       },
       extra_range_buttons = extra_range_buttons,
       extra_tags_buttons = extra_tags_buttons,
   },
   chart = {
       name = CHART_NAME
   },
   navbar = page_utils.get_new_navbar_context(i18n("alerts_dashboard.alerts"), url, pages),
   csrf = ntop.getRandomCSRFValue(),
}

local context = {
   ifid = ifid,
   ui_utils = ui_utils,
   template_utils = template_utils,
   widget_gui_utils = widget_gui_utils,
   json = json,
   opsep = tag_utils.SEPARATOR,
   isPro = ntop.isPro(),
   notes = notes,
   show_chart = true,
   show_cards = (status ~= "engaged") and ntop.isPro(),
   endpoint_cards = endpoint_cards,

   -- buttons
   show_permalink = (page ~= 'all'),
   show_download = (page ~= 'all'),
   show_acknowledge_all =  (page ~= 'all') and (status == "historical"),
   show_delete_all = (page ~= 'all') and (status ~= "engaged"),
   show_actions = (page ~= 'all'),
   actions = {
       show_settings = (page ~= 'system') and isAdministrator(),
       show_flows = (page == 'host'),
       show_historical = ((page == 'host') or (page == 'flow')) and ntop.isEnterpriseM() and hasClickHouseSupport(),
       show_pcap_download = traffic_extraction_available and page == 'flow',
       show_disable = ((page == 'host') or (page == 'flow')) and isAdministrator() and ntop.isEnterpriseM(),
       show_acknowledge = (page ~= 'all') and (status == "historical") and isAdministrator(),
       show_delete = (page ~= 'all') and (status ~= "engaged") and isAdministrator(),
       show_info = (page == 'flow'),
       show_snmp_info = (page == 'snmp_device')
   },

   show_tot_records = true,

   range_picker = {
       ifid = ifid,
       default = status ~= "engaged" and "30min" or "1week",
       earliest_available_epoch = earliest_available_epoch,
       epoch_begin = epoch_begin,
       epoch_end = epoch_end,
       datasource_params = datasource.params,
       refresh_enabled = checkbox_checked,
       opsep = tag_utils.SEPARATOR,
       dont_refresh_full_page = true,
       show_auto_refresh = (page ~= 'all'),
       tags = {
           enabled = (page ~= 'all'),
           tag_operators = tag_utils.tag_operators,
           view_only = true,
           defined_tags = defined_tags[page],
           values = initial_tags,
           i18n = {
               auto_refresh_descr = i18n("auto_refresh_descr"),
               enable_auto_refresh = auto_refresh_text,
               alert_id = i18n("db_search.tags.alert_id"),
               severity = i18n("db_search.tags.severity"),
               score = i18n("db_search.tags.score"),
               l7_proto = i18n("db_search.tags.l7proto"),
               cli_ip = i18n("db_search.tags.cli_ip"),
               srv_ip = i18n("db_search.tags.srv_ip"),
               cli_name = i18n("db_search.tags.cli_name"),
               srv_name = i18n("db_search.tags.srv_name"),
               cli_port = i18n("db_search.tags.cli_port"),
               srv_port = i18n("db_search.tags.srv_port"),
               ip_version = i18n("db_search.tags.ip_version"),
               ip = i18n("db_search.tags.ip"),
               name = i18n("db_search.tags.name"),
               network_name = i18n("db_search.tags.network_name"),
               subtype = i18n("alerts_dashboard.element"),
               role = i18n("db_search.tags.role"),
               role_cli_srv = i18n("db_search.tags.role_cli_srv"),
               l7_error_id = i18n("db_search.tags.error_code"),
               community_id = i18n("db_search.tags.community_id"),
               confidence = i18n("db_search.tags.confidence"),
               traffic_direction = i18n("db_search.tags.traffic_direction"),
          }
       },
       presets = {
           five_mins = false,
           month = false,
           year = false
       },
       extra_range_buttons = extra_range_buttons,
       extra_tags_buttons = extra_tags_buttons,
   },
   chart = {
       name = CHART_NAME
   },
   datatable = datatable,
   navbar = json.encode(page_utils.get_new_navbar_context(i18n("alerts_dashboard.alerts"), url, pages)),
   extra_js = "pages/alerts/datatable.js.template",
   extra_js_context = {
       ifid = ifid,
       entity = page,
       alert_status = status,
       datatable = datatable,
       alert_details_url = alert_details_url,
   }
}

if page == "flow" then
   local json_context = json.encode(context_2)
   template_utils.render("pages/vue_page.template", { vue_page_name = "PageAlertStats", page_context = json_context })
else
   template_utils.render("pages/components/datatable.template", context)
end
-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
