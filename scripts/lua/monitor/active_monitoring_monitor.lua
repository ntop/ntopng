--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local script_manager = require("script_manager")
local ui_utils = require("ui_utils")
local template = require("template_utils")
local json = require("dkjson")
local active_monitoring_utils = require "am_utils"

local graph_utils = require("graph_utils")
local auth = require "auth"

local ts_creation = script_manager.systemTimeseriesEnabled()

if not isAllowedSystemInterface() then return end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.active_monitoring)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local host = _GET["am_host"]

local page = _GET["page"] or 'overview'
local measurement = _GET["measurement"]
local ifid = interface.getId()
local ifStats = interface.getStats()
local ifname = ""
if (ifStats and not isEmptyString(ifStats.name)) then
    ifname = ifStats.name
end
local base_url = script_manager.getMonitorUrl("active_monitoring_monitor.lua") .. "?ifid=" .. ifid
local url = base_url
local info = ntop.getInfo()
local measurement_info


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


local navbar_title = ui_utils.create_navbar_title(title, host_label, "/lua/monitor/active_monitoring_monitor.lua")

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
        hidden = not areAlertsEnabled(),
        active = page == "alerts",
        page_name = "alerts",
        label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
	url = ntop.getHttpPrefix().."/lua/alert_stats.lua?&status=engaged&page=am_host"
    }
})

-- #######################################################

if (page == "overview") then
    local measurements_info = {}

    -- This information is required in active_monitoring_utils.js in order to properly
    -- render the template
    for key, info in pairs(active_monitoring_utils.getMeasurementsInfo()) do
        if key == "vulnerability_scan" or key == "cve_changes_detected" or key == "ports_changes_detected" then
            goto continue
        end

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

        ::continue::
    end

    local context = {
        json = json,
        template_utils = template,
        script_manager = script_manager,
        generate_select = generate_select,
        ui_utils = ui_utils,
        default_ifname = ifname,
        am_stats = {
            measurements_info = measurements_info,
            get_host = (_GET["am_host"] or ""),
            notes = {
                i18n("active_monitoring_stats.note3", {product = info.product}),
                i18n("active_monitoring_stats.note_alert"),
		i18n("active_monitoring_stats.note_alert_dashed"),
                i18n("active_monitoring_stats.note_availability")
            }
        }
    }
    -- template render
    template.render("active_monitoring_stats.template", context)

elseif ((page == "historical") and (host ~= nil) and (measurement_info ~= nil)) then
   local host_value = host.host .. ",metric:" .. host.measurement
   graph_utils.drawNewGraphs({ifid = -1, host = host_value})

end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
