--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_utils = require "graph_utils"
local ts_utils = require("ts_utils")
local page_utils = require("page_utils")

local asn = tonumber(_GET["asn"])
local ifId = interface.getId()
local as_info = interface.getASInfo(asn) or {}
local asname = as_info["asname"]
local base_url = ntop.getHttpPrefix() .. "/lua/as_details.lua"
local label = (asn or '') .. ''
local default_schema = "asn:traffic"

if not isEmptyString(asname) then
    label = label .. " [" .. asname .. "]"
end

sendHTTPContentTypeHeader('text/html')

-- ##############################################

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.autonomous_systems)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local nav_url = ntop.getHttpPrefix() .. "/lua/as_details.lua?asn=" .. tonumber(asn)
local title = i18n("as_details.as") .. ": " .. label

page_utils.print_navbar(title, nav_url, {{
    active = false,
    page_name = "flows",
    url = ntop.getHttpPrefix() .. "/lua/as_stats.lua",
    label = '<i class="fas fa-lg fa-home" data-bs-toggle="tooltip" data-bs-placement="top" title="' ..
        i18n("as_stats.autonomous_systems") .. '></i>'
}, {
    active = true,
    page_name = "historical",
    label = "<i class='fas fa-lg fa-chart-area'></i>"
}})

-- ##############################################

local source_value_object = {
	asn = tonumber(asn),
	ifid = interface.getId()
}
graph_utils.drawNewGraphs(source_value_object)

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
