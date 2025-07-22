--
-- (C) 2013-24 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local template_utils = require("template_utils")
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
    showTimeseries = areASTimeseriesEnabled(ifid)
}

local json_context = json.encode(context)

if page == "overview" or not page then
   -- Edit page-as-stats.vue (see http_src/vue/ntop_vue.js)
    template_utils.render("pages/vue_page.template", {
        vue_page_name = "PageAsStats",
        page_context = json_context
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
