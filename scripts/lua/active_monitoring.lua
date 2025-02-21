--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "check_redis_prefs"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local active_monitoring_utils = require "am_utils"
local json = require("dkjson")

-- ###########################################

if not isAllowedSystemInterface() then
    return
end

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.active_monitoring)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ###########################################

local page = _GET["page"] or 'overview'
local host = _GET["host"]
local measurement = _GET["measurement"]
local is_infrastructure = _GET["is_infrastructure"]

-- ###########################################

local ifid = interface.getId()
local base_url = "lua/active_monitoring.lua?ifid=" .. ifid
local title = i18n("graphs.active_monitoring")
local host_label = ''

-- Host is used by the charts too, so we have to check a couple of characters to correctly format it
-- because it can be manipulated by drawNewGraphs
if not isEmptyString(host) then
    local tmp = string.split(host, ",metric:")
    if tmp then
        host = tmp[1] -- The first entry is the real host
    end
end

if (not isEmptyString(host) and not isEmptyString(measurement)) then
    local tmp = active_monitoring_utils.getHost(host, measurement)
    if not isEmptyString(tmp) then
        host_label = active_monitoring_utils.formatAmHost(tmp.host, tmp.measurement, true)
    end
    if not isEmptyString(host_label) then
        title = string.format("<a href='%s/%s'>%s</a>", ntop.getHttpPrefix(), base_url, title)
        title = title .. " / " .. host_label
    end
end

page_utils.print_navbar(title, base_url, {{
    active = (page == "overview" or not page),
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"></i>",
    url = ntop.getHttpPrefix() .. "/" .. base_url
}, {
    hidden = (host == nil) or not areSystemTimeseriesEnabled(),
    active = page == "historical",
    page_name = "historical",
    label = "<i class='fas fa-lg fa-chart-area'></i>"
}, {
    hidden = not areAlertsEnabled(),
    active = page == "alerts",
    page_name = "alerts",
    label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
    url = ntop.getHttpPrefix() .. "/lua/alert_stats.lua?&status=engaged&page=am_host"
}})

-- #######################################################

if (page == "overview") then
    local json_context = json.encode({
        ifid = ifid,
        csrf = ntop.getRandomCSRFValue(),
        is_admin = isAdministrator(),
        timeseries_enabled = areSystemTimeseriesEnabled()
    })
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageActiveMonitoring",
        page_context = json_context
    })
elseif ((page == "historical") and (not isEmptyString(host))) then
    local graph_utils = require("graph_utils")
    local host_tag = host
    if not isEmptyString(measurement) then
        host_tag = host .. ",metric:" .. measurement
    elseif not isEmptyString(is_infrastructure) then
        host_tag = host .. ",metric:infrastructure"
    end
    graph_utils.drawNewGraphs({
        ifid = -1,
        host = host_tag
    })
end

-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
