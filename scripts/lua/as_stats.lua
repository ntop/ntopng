--
-- (C) 2013-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local template_utils = require("template_utils")
local graph_utils = require "graph_utils"
local page_utils = require "page_utils"
local json = require "dkjson"
require "lua_utils"

local page = _GET["page"]
local asn = _GET["asn"]

interface.select(ifname)

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- Get Asname
local as_info;
local as_name = ""

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

local breadcrumb

if page == "overview" or not page then
    breadcrumb = i18n("as_stats.autonomous_systems")
else
    
    local asn_string = ternary(asn == 0, tostring(asn),tostring(asn) .. " (" .. as_name .. ")")
    
    breadcrumb =  " ASN: " .. "<a href=".. ntop.getHttpPrefix().. "/lua/hosts_stats.lua?asn=" .. tostring(asn) .. "> " .. asn_string .. " </a>" 
end

page_utils.print_navbar(breadcrumb, ntop.getHttpPrefix() .. "/lua/as_stats.lua", {{
    active = page == "overview" or not page,
    page_name = "overview",
    label = "<i class=\"fas fa-lg fa-home\"  data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" ..
        i18n("as_stats.autonomous_systems") .. "\"></i>"
}, {
    active = page == "historical",
    hidden = isEmptyString(asn),
    page_name = "historical",
    label = "<i class='fas fa-lg fa-chart-area'></i>"
}})

local context = {
    ifid = interface.getId()
}

local json_context = json.encode(context)

if page == "overview" or not page then
   -- Edit page-as-stats.vue (see http_src/vue/ntop_vue.js)
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageAsStats",
        page_context = json_context
    })
else
    local source_value_object = {
        asn = asn,
        ifid = interface.getId()
    }
    graph_utils.drawNewGraphs(source_value_object)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
