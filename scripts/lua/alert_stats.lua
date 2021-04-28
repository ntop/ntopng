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
local Datasource = widget_gui_utils.datasource

local ifid = interface.getId()
local CHART_NAME = "alert-timeseries"

-- select the default page
local page = _GET["page"] or 'host' -- default
local status = _GET["status"] or "historical"

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

local disable_modal = "modal_alerts_filter_dialog.html"

if (page == "flow") then
    disable_modal = "modal_flow_alerts_filter_dialog.html"
elseif (page == "host") then
    disable_modal = "modal_host_alerts_filter_dialog.html"
end

local is_system_interface = page_utils.is_system_view()

-- default endpoints (host)
local endpoint_list = "/lua/rest/v1/get/host/alert/list.lua"
local endpoint_ts = "/lua/rest/v1/get/host/alert/ts.lua"

local pages = {
    {
        active = page == "host",
        page_name = "host",
        label = i18n("hosts"),
        endpoint_list = "/lua/rest/v1/get/host/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/host/alert/ts.lua",
	hidden = is_system_interface,
    },
    {
        active = page == "mac",
        page_name = "mac",
        label = i18n("discover.device"),
        endpoint_list = "/lua/rest/v1/get/mac/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/mac/alert/ts.lua",
	hidden = is_system_interface,
    },
    {
        active = page == "snmp_device",
        page_name = "snmp_device",
        label = i18n("snmp.snmp_devices"),
        endpoint_list = "/lua/pro/rest/v1/get/snmp/device/alert/list.lua",
        endpoint_ts = "/lua/pro/rest/v1/get/snmp/device/alert/ts.lua",
    },
    {
        active = page == "flow",
        page_name = "flow",
        label = i18n("flows"),
        endpoint_list = "/lua/rest/v1/get/flow/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/flow/alert/ts.lua",
	hidden = is_system_interface,
    },
    {
        active = page == "system",
        page_name = "system",
        label = i18n("system"),
        endpoint_list = "/lua/rest/v1/get/system/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/system/alert/ts.lua"
    },
    {
        active = page == "active_monitoring",
        page_name = "active_monitoring",
        label = i18n("active_monitoring_stats.active_monitoring"),
        endpoint_list = "/lua/rest/v1/get/active_monitoring/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/active_monitoring/alert/ts.lua"
    },
    {
        active = page == "interface",
        page_name = "interface",
        label = i18n("interface"),
        endpoint_list = "/lua/rest/v1/get/interface/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/interface/alert/ts.lua",
	hidden = is_system_interface,
    },
    {
        active = page == "network",
        page_name = "network",
        label = i18n("network_details.network"),
        endpoint_list = "/lua/rest/v1/get/network/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/network/alert/ts.lua",
	hidden = is_system_interface,
    },
    {
        active = page == "user",
        page_name = "user",
        label = i18n("nedge.user"),
        endpoint_list = "/lua/rest/v1/get/user/alert/list.lua",
        endpoint_ts = "/lua/rest/v1/get/user/alert/ts.lua",
    }
}

-- Iterate back to front to remove items if necessary
for i = #pages, 1, -1 do
   local page = pages[i]

   if page.hidden then
      table.remove(pages, i)
   elseif page.page_name == page then
      endpoint_list = page.endpoint_list
      endpoint_ts = page.endpoint_ts
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
    ["delete_alert_dialog"] = template_utils.gen("modal_confirm_dialog.html", {
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
    ["release_single_alert"] = template_utils.gen("modal_confirm_dialog.html", {
        dialog = {
            id      = "release_single_alert",
            title   = i18n("show_alerts.release_alert"),
            message = i18n("show_alerts.confirm_release_alert"),
            confirm = i18n("show_alerts.release_alert_action"),
            confirm_button = "btn-primary",
            custom_alert_class = "alert alert-primary",
            no_confirm_id = true
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

for tag_key, tag in pairs(defined_tags[page] or {}) do
    tag_utils.add_tag_if_valid(initial_tags, tag_key, tag, {})
end

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
        }
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
