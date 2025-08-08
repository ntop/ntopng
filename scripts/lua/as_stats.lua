--
-- (C) 2013-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local template_utils = require("template_utils")
local page_utils = require "page_utils"
local json = require "dkjson"
local graph_utils = require "graph_utils"
require "lua_utils"
require "check_redis_prefs"
local is_asn_mode_enabled = isASNModeEnabled()

local page = _GET["page"]
local asn = _GET["asn"]

interface.select(ifname)

sendHTTPContentTypeHeader('text/html')

-- if asn mode, render active entry: 'as', not interface
local menu = page_utils.menu_entries.autonomous_systems

if is_asn_mode_enabled then
    menu = page_utils.menu_entries.autonomous_systems_asn_mode
end

page_utils.print_header_and_set_active_menu_entry(menu)


dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- Get Asname
local as_info;
local as_name = ""
local ifid = interface.getId()

asn = tonumber(asn)
if (asn ~= nil) then
    as_info = interface.getASesInfo({detailsLevel = "high"})
    as_info = as_info["ASes"]
    end
    
if as_info ~= nil then
    for key, value in pairs(as_info) do

        if (value["asn"] == asn) then
        as_name = value["asname"]
        end
    end
end

local breadcrumb = i18n("as_stats.autonomous_systems")

page_utils.print_navbar(breadcrumb, ntop.getHttpPrefix() .. "/lua/as_stats.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("as_stats.autonomous_systems") .. "\"></i>"
}, {
    url = ntop.getHttpPrefix() .. "/lua/as_stats.lua?page=historical",
    active = page == "historical",
    page_name = "historical",
    label = "<i class='fas fa-lg fa-chart-area'></i>"
}})

local show_sankey = false
local current_ifid = ifid

if interface.isView() then
    for ifid, ifname in pairs(interface.getIfNames()) do 
        interface.select(ifid)
        if (interface.isZMQInterface() and interface.isViewed()) then
            show_sankey = true
            break
        end
    end
    interface.select(current_ifid)
elseif interface.isZMQInterface() then
    show_sankey = true
end

local context = {
    ifid = ifid,
    showSankey = show_sankey,
    csrf = ntop.getRandomCSRFValue(),
    isEnterprise = ntop.isEnterprise(),
    showTimeseries = areASTimeseriesEnabled(ifid),
    ASNModeEnabled = is_asn_mode_enabled
}

local json_context = json.encode(context)

if page == "overview" or not page then
   -- Edit page-as-stats.vue (see http_src/vue/ntop_vue.js)
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageAsStats",
        page_context = json_context
    })
elseif page == "historical" then
    local source_value_object = {
        ifid = interface.getId()
    }
    graph_utils.drawNewGraphs(source_value_object)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
