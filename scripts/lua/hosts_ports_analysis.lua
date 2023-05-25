--
-- (C) 2013-23 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local if_stats = interface.getStats()

if (if_stats.has_seen_pods or if_stats.has_seen_containers) then
    -- Use a different flows page
    dofile(dirs.installdir .. "/scripts/lua/inc/ebpf_flows_stats.lua")
    return
end

require "lua_utils"
require "flow_utils"

local page_utils = require("page_utils")
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(
    page_utils.menu_entries.server_ports_analysis)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local draw = _GET["draw"] or 0
local sort = _GET["sort"] or "bytes_rcvd"
local order = _GET["order"] or "asc"
local start = _GET["start"] or 0
local length = _GET["length"] or 10

local page = _GET["page"]

local ifId = interface.getId()

local base_url = ntop.getHttpPrefix() .. "/lua/hosts_ports_analysis.lua"


page_utils.print_navbar(i18n('active_ports'), base_url .. "?", {{
    active = page == "live" or page == nil,
    page_name = "live",
    label = "<i class=\"fas fa-lg fa-home\"></i>",
    base_url .. "?page=live",

}, {
    url = base_url .. "?page=historical",
    active = page == "historical",
    page_name = "historical",
    label = i18n("analysis")
}})

if (page == "live" or page == nil) then
    
    template.render("pages/hosts_ports_analysis.template", {
        ifid = ifId,
        draw = draw,
        sort = sort,
        order = order,
        start = start,
        length = length,
        is_live = true
    })
else
    -- Historical

    template.render("pages/hosts_ports_analysis.template", {
        ifid = ifId,
        draw = draw,
        sort = sort,
        order = order,
        start = start,
        length = length,
        is_live = false
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
