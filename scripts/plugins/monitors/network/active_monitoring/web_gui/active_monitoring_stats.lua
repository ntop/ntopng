--
-- (C) 2013-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local alert_consts = require("alert_consts")
local plugins_utils = require("plugins_utils")
local ui_utils = require("ui_utils")
local template = require("template_utils")
local json = require("dkjson")
local active_monitoring_utils = plugins_utils.loadModule("active_monitoring",
                                                         "am_utils")
local active_monitoring_pools = require("active_monitoring_pools")
local am_pool = active_monitoring_pools:create()

local graph_utils = require("graph_utils")
local alert_utils = require("alert_utils")
local user_scripts = require("user_scripts")
local auth = require "auth"

local ts_creation = plugins_utils.timeseriesCreationEnabled()

if not isAllowedSystemInterface() then return end

sendHTTPContentTypeHeader('text/html')

page_utils.set_system_view(true)
page_utils.set_active_menu_entry(page_utils.menu_entries.active_monitor)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local host = _GET["am_host"]

local page = _GET["page"] or ('overview')
local measurement = _GET["measurement"]

local base_url = plugins_utils.getUrl("active_monitoring_stats.lua") .. "?ifid=" .. getInterfaceId(ifname)
local url = base_url
local info = ntop.getInfo()
local measurement_info

if (not user_scripts.isSystemScriptEnabled("active_monitoring")) then
    -- The active monitoring is disabled
    print [[<div class="alert alert-warning" role="alert">]]
    print(i18n("host_config.active_monitor_enable", {
        url = ntop.getHttpPrefix() ..
            '/lua/admin/edit_configset.lua?confset_id=0&subdir=system&user_script=active_monitoring#all'
    }))
    print [[</div>]]

    dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

    return
end

if (not isEmptyString(host) and not isEmptyString(measurement)) then
   host = active_monitoring_utils.getHost(host, measurement)
   if host then
      measurement_info = active_monitoring_utils.getMeasurementInfo(host.measurement)
   end
else
    host = nil
end

if host then
    url = url .. "&am_host=" .. host.host .. "&measurement=" .. host.measurement
end

local title = i18n("graphs.active_monitoring")
local host_label = ""

if (host ~= nil) then
    host_label = active_monitoring_utils.formatAmHost(host.host, host.measurement, true)
end

if auth.has_capability(auth.capabilities.active_monitoring) then
    if (_POST["action"] == "reset_config") then
        active_monitoring_utils.resetConfig()
    end
end


local navbar_title = ui_utils.create_navbar_title(title, host_label, "/plugins/active_monitoring_stats.lua")

page_utils.print_navbar(navbar_title, url, {
    {
        active = page == "overview" or not page,
        page_name = "overview",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = (host ~= nil and url or base_url)
    }, {
        hidden = (host == nil) or not ts_creation,
        active = page == "historical",
        page_name = "historical",
        label = "<i class='fas fa-lg fa-chart-area'></i>"
    }, {
        hidden = (host ~= nil) or not auth.has_capability(auth.capabilities.active_monitoring) or
            not plugins_utils.hasAlerts(getSystemInterfaceId(), {
                entity = alert_consts.alertEntity("am_host")
            }),
        active = page == "alerts",
        page_name = "alerts",
        label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>"
    }
})

-- #######################################################

if (page == "overview") then

    -- Create a filter list to use inside the overview page
    -- to filter the datatable
    local pool_filters = {}
    for key, value in pairs(am_pool:get_all_pools()) do
        pool_filters[#pool_filters + 1] =
            {key = "pool-" .. key, label = value.name, regex = tostring(value.pool_id)}
    end

    local measurements_info = {}

    -- This information is required in active_monitoring_utils.js in order to properly
    -- render the template
    for key, info in pairs(active_monitoring_utils.getMeasurementsInfo()) do
        measurements_info[key] = {
            label = i18n(info.i18n_label) or info.i18n_label,
            granularities = active_monitoring_utils.getAvailableGranularities(
                key),
            operator = info.operator,
            unit = i18n(info.i18n_unit) or info.i18n_unit,
            force_host = info.force_host,
            max_threshold = info.max_threshold,
            default_threshold = info.default_threshold
        }
    end

    local context = {
        json = json,
        template_utils = template,
        plugins_utils = plugins_utils,
        generate_select = generate_select,
        ui_utils = ui_utils,
        am_stats = {
            pool_filters = pool_filters,
            measurements_info = measurements_info,
            get_host = (_GET["am_host"] or ""),
            pools = am_pool,
            notes = {
                i18n("active_monitoring_stats.note3", {product = info.product}),
                i18n("active_monitoring_stats.note_alert"),
                i18n("active_monitoring_stats.note_availability")
            }
        }
    }
    -- template render
    print(plugins_utils.renderTemplate("active_monitoring", "active_monitoring_stats.template", context))

elseif ((page == "historical") and (host ~= nil) and (measurement_info ~= nil)) then

    local suffix = "_" .. host.granularity
    local schema = _GET["ts_schema"] or ("am_host:val" .. suffix)
    local selected_epoch = _GET["epoch"] or ""
    local tags = {
        ifid = getSystemInterfaceId(),
        host = host.host,
        metric = host.measurement --[[ note: measurement is a reserved InfluxDB keyword ]]
    }
    local am_ts_label
    local am_metric_label
    local notes = {{content = i18n("graphs.red_line_unreachable")}}

    if measurement_info.i18n_am_ts_label then
        am_ts_label = i18n(measurement_info.i18n_am_ts_label) or
                          measurement_info.i18n_am_ts_label
    else
        -- Fallback
        am_ts_label = i18n("graphs.num_ms_rtt")
    end

    if measurement_info.i18n_am_ts_metric then
        am_metric_label = i18n(measurement_info.i18n_am_ts_metric) or
                              measurement_info.i18n_am_ts_metric
    else
        am_metric_label = i18n("flow_details.round_trip_time")
    end

    url = url .. "&page=historical"

    local timeseries = {
        {
            schema = "am_host:val" .. suffix,
            label = am_ts_label,
            value_formatter = measurement_info.value_js_formatter or
                "NtopUtils.fmillis",
            metrics_labels = {am_metric_label},
            show_unreachable = true -- Show the unreachable host status as a red line
        }
    }

    for _, note in ipairs(measurement_info.i18n_chart_notes or {}) do
        notes[#notes + 1] = {content = i18n(note) or note}
    end

    for _, ts_info in ipairs(measurement_info.additional_timeseries or {}) do
        -- Add the per-granularity suffix (e.g. _min)
        ts_info.schema = ts_info.schema .. suffix

        timeseries[#timeseries + 1] = ts_info
    end

    graph_utils.drawGraphs(getSystemInterfaceId(), schema, tags, _GET["zoom"],
                           url, selected_epoch,
                           {timeseries = timeseries, notes = notes})

elseif ((page == "alerts") and
    auth.has_capability(auth.capabilities.active_monitoring)) then
    local old_ifname = ifname
    local ts_utils = require("ts_utils")
    local influxdb = ts_utils.getQueryDriver()

    -- NOTE: system interface must be manually sected and then unselected
    interface.select(getSystemInterfaceId())

    _GET["ifid"] = getSystemInterfaceId()
    _GET["entity"] = alert_consts.alertEntity("am_host")

    if host then
        _GET["entity_val"] = active_monitoring_utils.getAmHostKey(host.host,
                                                                  host.measurement)
    end

    alert_utils.drawAlerts({is_standalone = true})

    interface.select(old_ifname)
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
