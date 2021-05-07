--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local ui_utils = require "ui_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local widget_gui_utils = require "widget_gui_utils"
local tag_utils = require "tag_utils"
local alert_entities = require "alert_entities"
local Datasource = widget_gui_utils.datasource

local ifid = interface.getId()
-- Used to print badges next to navbar entries
local num_alerts_engaged_by_entity = interface.getStats()["num_alerts_engaged_by_entity"]

local CHART_NAME = "alert-timeseries"

-- select the default page
local page = _GET["page"] or 'all'
local status = _GET["status"]

-- If the status is not explicitly set, it is chosen between (engaged when there are engaged alerts) or historical when
-- no engaged alert is currently active
if not status then
   if alert_entities[page] and num_alerts_engaged_by_entity[tostring(alert_entities[page].entity_id)] then
      status = "engaged"
   else
      status = "historical"
   end
end

local time = os.time()

-- initial epoch_begin is set as now - 30 minutes
local epoch_begin = _GET["epoch_begin"] or time - 1800
local epoch_end = _GET["epoch_end"] or time

--------------------------------------------------------------

local network_name = _GET["network_name"]
local l7_proto = _GET["l7_proto"]
local cli_ip = _GET["cli_ip"]
local srv_ip = _GET["srv_ip"]
local host_ip = _GET["ip"]

--------------------------------------------------------------

sendHTTPContentTypeHeader('text/html')

local disable_modal = "pages/modals/modal_alerts_filter_dialog.html"

local is_system_interface = page_utils.is_system_view()

-- default endpoints (host)
local endpoint_list = "/lua/rest/v1/get/host/alert/list.lua"
local endpoint_ts = "/lua/rest/v1/get/host/alert/ts.lua"

local pages = {
   {
        active = page == "all",
        page_name = "all",
        label = i18n("all"),
        endpoint_list = "/lua/rest/v1/get/all/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/all/alert/ts.lua",
   },
   {
        active = page == "host",
        page_name = "host",
        label = alert_entities.host.label,
        endpoint_list = "/lua/rest/v1/get/host/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/host/alert/ts.lua",
	hidden = is_system_interface,
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.host.entity_id)]
    },
    {
        active = page == "interface",
        page_name = "interface",
        label = alert_entities.interface.label,
        endpoint_list = "/lua/rest/v1/get/interface/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/interface/alert/ts.lua",
	hidden = is_system_interface,
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.interface.entity_id)]
    },
    {
        active = page == "network",
        page_name = "network",
        label = alert_entities.network.label,
        endpoint_list = "/lua/rest/v1/get/network/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/network/alert/ts.lua",
	hidden = is_system_interface,
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.network.entity_id)]
    },
    {
        active = page == "snmp_device",
        page_name = "snmp_device",
        label = alert_entities.snmp_device.label,
        endpoint_list = "/lua/pro/rest/v1/get/snmp/device/alert/list.lua",
        endpoint_ts = "/lua/pro/rest/v1/get/snmp/device/alert/ts.lua",
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.snmp_device.entity_id)]
    },
    {
        active = page == "flow",
        page_name = "flow",
        label = alert_entities.flow.label,
        endpoint_list = "/lua/rest/v1/get/flow/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/flow/alert/ts.lua",
	hidden = is_system_interface,
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.flow.entity_id)]
    },
    {
        active = page == "mac",
        page_name = "mac",
        label = alert_entities.mac.label,
        endpoint_list = "/lua/rest/v1/get/mac/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/mac/alert/ts.lua",
	hidden = is_system_interface,
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.mac.entity_id)]
    },
    {
        active = page == "system",
        page_name = "system",
        label = alert_entities.system.label,
        endpoint_list = "/lua/rest/v1/get/system/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/system/alert/ts.lua",
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.system.entity_id)]
    },
    {
        active = page == "am_host",
        page_name = "am_host",
        label = alert_entities.am_host.label,
        endpoint_list = "/lua/rest/v1/get/active_monitoring/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/active_monitoring/alert/ts.lua",
	badge_num = num_alerts_engaged_by_entity[tostring(alert_entities.am_host.entity_id)]
    },
    {
        active = page == "user",
        page_name = "user",
        label = alert_entities.user.label,
        endpoint_list = "/lua/rest/v1/get/user/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/user/alert/ts.lua",
	hidden = is_system_interface,
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
   end
end

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?"

page_utils.print_navbar(i18n("alerts_dashboard.alerts"), url, pages)

widget_gui_utils.register_timeseries_bar_chart(CHART_NAME, 0, {
    Datasource(endpoint_ts, {
        ifid = ifid,
        epoch_begin = epoch_begin,
        epoch_end = epoch_end,
        status = status,
        cli_ip = cli_ip,
        srv_ip = srv_ip,
        l7_proto = l7_proto,
        ip = host_ip,
        network_name = network_name
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
    ["alerts_filter_dialog"] = template_utils.gen(disable_modal, {
        dialog = {
            id = "alerts_filter_dialog",
            title = i18n("show_alerts.filter_alert"),
            message	= i18n("show_alerts.confirm_filter_alert"),
            delete_message = i18n("show_alerts.confirm_delete_filtered_alerts"),
            delete_alerts = i18n("delete_disabled_alerts"),
            alert_filter = "default_filter",
            confirm = i18n("filter"),
            confirm_button = "btn-warning",
            custom_alert_class = "alert alert-warning",
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
    })
}

local defined_tags = {
    ["host"] = {
        ip = {'eq'}
    },
    ["mac"] = {
    },
    ["snmp_device"] = {

    },
    ["flow"] = {
        l7_proto  = {'eq'},
        cli_ip = {'eq'},
        srv_ip = {'eq'}
    },
    ["system"] = {

    },
    ["active_monitoring"] = {

    },
    ["interface"] = {

    },
    ["user"] = {

    },
    ["network"] = {
        network_name = {'eq'}
    }
}

local initial_tags = {}
local formatters = {
    l7_proto = function(proto) return interface.getnDPIProtoName(tonumber(proto)) end
}

for tag_key, tag in pairs(defined_tags[page] or {}) do
    tag_utils.add_tag_if_valid(initial_tags, tag_key, tag, formatters)
end

local base_url = build_query_url({'status', 'page', 'epoch_begin', 'epoch_end'}) 

local toggle_engaged_alert = ([[
    <div class='d-flex align-items-center mr-1'>
        <div class="btn-group" role="group">
            <a href=']] .. base_url .. [[&status=historical&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status == "historical", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.past") .. [[</a>
            <a href=']] .. base_url .. [[&status=engaged&page=]].. page ..[[' class="btn btn-sm ]].. ternary(status ~= "historical", "btn-primary active", "btn-secondary") ..[[">]] .. i18n("show_alerts.engaged") .. [[</a>
        </div> 
    </div>
]])
    
local context = {
    template_utils = template_utils,
    json = json,
    ui_utils = ui_utils,
    widget_gui_utils = widget_gui_utils,
    ifid = ifid,
    range_picker = {
        default = "30min",
        tags = {
            tag_operators = {tag_utils.tag_operators.eq},
            defined_tags = defined_tags[page],
            values = initial_tags,
            i18n = {
                l7_proto = i18n("tags.l7proto"),
                cli_ip = i18n("tags.cli_ip"),
                srv_ip = i18n("tags.srv_ip"),
                ip = i18n("tags.ip"),
                network_name = i18n("tags.network")
            }
        },
        presets = {
            five_mins = false,
            month = false,
            year = false
        },
        extra_html = toggle_engaged_alert
    },
    chart = {
        name = CHART_NAME
    },
    datatable = {
        name = page .. "-alerts-table",
        initialLength = getDefaultTableSize(),
        table = template_utils.gen(string.format("pages/alerts/families/%s/table.template", page), {}),
        js_columns = template_utils.gen(string.format("pages/alerts/families/%s/table.js.template", page), {}),
        datasource = Datasource(endpoint_list, {
            ifid = ifid,
            epoch_begin = epoch_begin,
            epoch_end = epoch_end,
            status = status,
            cli_ip = cli_ip,
            srv_ip = srv_ip,
            l7_proto = l7_proto,
            ip = host_ip,
            network_name = network_name
        }),
        actions = {
            disable = (page ~= "host" and page ~= "flow")
        },
        modals = modals,
    },
    alert_stats = {
        entity = page,
        status = status
    }
}

template_utils.render("pages/alerts/alert-stats.template", context)

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
