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
local alert_severities = require "alert_severities"
local Datasource = widget_gui_utils.datasource
local alert_store_utils = require "alert_store_utils"
local alert_utils = require "alert_utils"
local alert_store = require "alert_store"

local ifid = interface.getId()

local CHART_NAME = "alert-timeseries"

-- select the default page
local page = _GET["page"] or 'all'
local status = _GET["status"]

-- Used to print badges next to navbar entries
local num_alerts_engaged = interface.getStats()["num_alerts_engaged"]
local num_alerts_engaged_by_entity = interface.getStats()["num_alerts_engaged_by_entity"]
local num_alerts_engaged_cur_entity = alert_entities[page] and num_alerts_engaged_by_entity[tostring(alert_entities[page].entity_id)] or 0

-- If the status is not explicitly set, it is chosen between (engaged when there are engaged alerts) or historical when
-- no engaged alert is currently active
if not status then
   -- Default to historical
   status = "historical"

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
end

local time = os.time()

-- initial epoch_begin is set as now - 30 minutes for historical, or as 1 week for engaged
local epoch_begin = _GET["epoch_begin"] or time - (status ~= "engaged" and 1800 or 60 * 60 * 24 * 7)
local epoch_end = _GET["epoch_end"] or time
local time_range_query = "epoch_begin="..epoch_begin.."&epoch_end="..epoch_end

--------------------------------------------------------------

local alert_id = _GET["alert_id"]
local severity = _GET["severity"]
local ip_version = _GET["ip_version"]
local host_ip = _GET["ip"]
local cli_ip = _GET["cli_ip"]
local srv_ip = _GET["srv_ip"]
local cli_port = _GET["cli_port"]
local srv_port = _GET["srv_port"]
local l7_proto = _GET["l7_proto"]
local network_name = _GET["network_name"]
local role = _GET["role"]
local role_cli_srv = _GET["role_cli_srv"]
local subtype = _GET["subtype"]

--------------------------------------------------------------

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
	hidden = is_system_interface or not require "host_alert_store".new():has_alerts(),
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
	hidden = not require "interface_alert_store".new():has_alerts(),
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
	hidden = is_system_interface or not require "network_alert_store".new():has_alerts(),
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
	hidden = not is_system_interface or not ntop.isPro() or not require "snmp_device_alert_store".new():has_alerts(),
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
	hidden = is_system_interface or not require "flow_alert_store".new():has_alerts(),
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
	hidden = is_system_interface or not require "mac_alert_store".new():has_alerts(),
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
	hidden = not is_system_interface or not require "system_alert_store".new():has_alerts(),
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
	hidden = not is_system_interface or not require "am_alert_store".new():has_alerts(),
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
	hidden = not is_system_interface or not require "user_alert_store".new():has_alerts(),
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

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?"

page_utils.print_navbar(i18n("alerts_dashboard.alerts"), url, pages)

widget_gui_utils.register_timeseries_area_chart(CHART_NAME, 0, {
    Datasource(endpoint_ts, {
        ifid = ifid,
        epoch_begin = epoch_begin,
        epoch_end = epoch_end,
        status = status,
        alert_id = alert_id,
        severity = severity,
        ip_version = ip_version,
        ip = host_ip,
        cli_ip = cli_ip,
        srv_ip = srv_ip,
        cli_port = cli_port,
        srv_port = srv_port,
        l7_proto = l7_proto,
        network_name = network_name,
        role = role,
	role_cli_srv = role_cli_srv,
	subtype = subtype,
    })
})

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
    ["alerts_filter_dialog"] = template_utils.gen("pages/modals/modal_alerts_filter_dialog.html", {
        dialog = {
            id = "alerts_filter_dialog",
            title = i18n("show_alerts.filter_alert"),
            message	= i18n("show_alerts.confirm_filter_alert"),
            delete_message = i18n("show_alerts.confirm_delete_filtered_alerts"),
            delete_alerts = i18n("delete_disabled_alerts"),
            alert_filter = "default_filter",
            confirm = i18n("filter"),
            confirm_button = "btn-warning",
            custom_alert_class = "alert alert-danger",
            entity = page
        }
    }),
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
    ["delete-alerts-modal"] = template_utils.gen("pages/modals/alerts/delete_alerts.template", {
	    dialog={
            id      = "delete-alerts-modal",
            title   = i18n("delete_alerts"),
            label   = "",
            message = i18n("show_alerts.confirm_delete_alerts"),
            cancel  = i18n("cancel"),
	        apply   = i18n("delete")
	    }
    }),
    ["acknowledge-alerts-modal"] = template_utils.gen("pages/modals/alerts/acknowledge_alerts.template",{
	    dialog={
            id      = "acknowledge-alerts-modal",
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
    ip_version = {'eq','neq'},
    ip = {'eq','neq'},
    port = {'eq','neq'},
    l7_proto  = {'eq','neq'},
    role = {'eq'},
    role_cli_srv = {'eq'},
    text = {'eq','neq'},
}

local defined_tags = {
    ["host"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
        ip_version = operators_by_filter.ip_version,
        ip = operators_by_filter.ip,
        role = operators_by_filter.role,
	role_cli_srv = operators_by_filter.role_cli_srv,
    },
    ["mac"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
    },
    ["snmp_device"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
    },
    ["flow"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
        l7_proto  = operators_by_filter.l7_proto,
        ip_version = operators_by_filter.ip_version,
        ip = operators_by_filter.ip,
        cli_ip = operators_by_filter.ip,
        srv_ip = operators_by_filter.ip,
	cli_port = operators_by_filter.port,
	srv_port = operators_by_filter.port,
	role = operators_by_filter.role,
    },
    ["system"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
    },
    ["am_host"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
    },
    ["interface"] = {
        alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
       	subtype = operators_by_filter.text,
    },
    ["user"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
    },
    ["network"] = {
	alert_id = operators_by_filter.alert_id,
	severity = operators_by_filter.severity,
        network_name = operators_by_filter.text,
    }
}

local initial_tags = {}

local formatters = {
   severity = function(severity) return (i18n(alert_consts.alertSeverityById(tonumber(severity)).i18n_title)) end,
   role = function(role) return (i18n(role)) end,
   role_cli_srv = function(role) return (i18n(role)) end,
}
if page ~= "all" then
   formatters.l7_proto = function(proto) return interface.getnDPIProtoName(tonumber(proto)) end
   formatters.alert_id = function(alert_id) return (alert_consts.alertTypeLabel(tonumber(alert_id), true, alert_entities[page].entity_id) or alert_id) end
end

for tag_key, operators in pairs(defined_tags[page] or {}) do
   tag_utils.add_tag_if_valid(initial_tags, tag_key, operators, formatters, 'tags')
end

local base_url = build_query_url({'status', 'page', 'epoch_begin', 'epoch_end'}) 

local extra_range_buttons = [[
    <div class='d-flex align-items-center me-1'>
        <div class="btn-group" id="statusSwitch" role="group">
            <a href=']] .. base_url .. [[&]]..time_range_query .. [[&status=historical&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "historical", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.past") .. [[</a>
            <a href=']] .. base_url .. [[&]]..time_range_query .. [[&status=acknowledged&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "acknowledged", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.acknowledged") .. [[</a>
            <a href=']] .. base_url .. [[&]]..time_range_query .. [[&status=engaged&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "engaged", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.engaged") .. ternary(num_alerts_engaged_cur_entity > 0, string.format('<span class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">%u</span>', num_alerts_engaged_cur_entity), "") .. [[</a>
        </div>
    </div>
]]

local available_filter_types = {}
local all_alert_types = {}
local extra_tags_buttons = ""
if page ~= "all" then
   extra_tags_buttons = [[
    <button class="btn btn-link" aria-controls="]]..page..[[-alerts-table" type="button" id="btn-add-alert-filter" onclick="alertStats.filterModalShow()"><span><i class="fas fa-plus" data-original-title="" title="]]..i18n("alerts_dashboard.add_filter")..[["></i></span>
    </button>
   ]]

   local alert_store_instances = alert_store_utils.all_instances_factory()
   if alert_store_instances[alert_entities[page].alert_store_name] then
      local alert_store_instance = alert_store_instances[alert_entities[page].alert_store_name]
      available_filter_types = alert_store_instance:get_available_filters()
      all_alert_types = alert_consts.getAlertTypesInfo(alert_entities[page].entity_id)
   end
end

local context = {
    template_utils = template_utils,
    json = json,
    ui_utils = ui_utils,
    opsep = tag_utils.SEPARATOR,
    widget_gui_utils = widget_gui_utils,
    ifid = ifid,
    isPro = ntop.isPro(),
    range_picker = {
        default = status ~= "engaged" and "30min" or "1week",
        tags = {
	    enabled = (page ~= 'all'),
            tag_operators = tag_utils.tag_operators,
            view_only = true,
            defined_tags = defined_tags[page],
            values = initial_tags,
            i18n = {
	        alert_id = i18n("tags.alert_id"),
                severity = i18n("tags.severity"),
                l7_proto = i18n("tags.l7proto"),
                cli_ip = i18n("tags.cli_ip"),
                srv_ip = i18n("tags.srv_ip"),
                cli_port = i18n("tags.cli_port"),
                srv_port = i18n("tags.srv_port"),
                ip_version = i18n("tags.ip_version"),
                ip = i18n("tags.ip"),
                network_name = i18n("tags.network_name"),
		subtype = i18n("alerts_dashboard.subject"),
                role = i18n("tags.role"),
		role_cli_srv = i18n("tags.role_cli_srv"),
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
    datatable = {
        show_admin_controls = isAdministrator(),
	name = page .. "-alerts-table",
        initialLength = getDefaultTableSize(),
        table = template_utils.gen(string.format("pages/alerts/families/%s/table.template", page), {}),
        js_columns = template_utils.gen(string.format("pages/alerts/families/%s/table.js.template", page), {}),
	endpoint_list = endpoint_list,
	endpoint_delete = endpoint_delete,
	endpoint_acknowledge = endpoint_acknowledge,
        datasource = Datasource(endpoint_list, {
            ifid = ifid,
            epoch_begin = epoch_begin,
            epoch_end = epoch_end,
            status = status,
            alert_id = alert_id,
            severity = severity,
            ip_version = ip_version,
            ip = host_ip,
            cli_ip = cli_ip,
            srv_ip = srv_ip,
	    cli_port = cli_port,
            srv_port = srv_port,
            l7_proto = l7_proto,
            network_name = network_name,
            role = role,
	    role_cli_srv = role_cli_srv,
	    subtype = subtype,
        }),
        actions = {
            disable = (page ~= "host" and page ~= "flow")
        },
        modals = modals,
    },
    alert_stats = {
        entity = page,
        status = status
    },
    filters = { -- Context for pages/modals/alerts/filters/add.template
       alert_utils = alert_utils,
       alert_consts = alert_consts,
       available_types = available_filter_types,
       severities = alert_severities,
       alert_types = all_alert_types,
       l7_protocols = interface.getnDPIProtocols(),
       operators_by_filter = operators_by_filter,
       tag_operators = tag_utils.tag_operators,
    }
}

template_utils.render("pages/alerts/alert-stats.template", context)

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
