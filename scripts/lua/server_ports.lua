--
-- (C) 2013-24 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local if_stats = interface.getStats()
if not ntop.isEnterpriseL() then
    return
end

require "lua_utils"
require "flow_utils"

local page_utils = require("page_utils")
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.server_ports)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local draw = _GET["draw"] or 0
local sort = _GET["sort"] or "bytes_rcvd"
local order = _GET["order"] or "asc"
local start = _GET["start"] or 0
local length = _GET["length"] or 10

local page = _GET["page"]

if isEmptyString(page) and ntop.isEnterpriseL() then
    page = "flows_sankey"
elseif isEmptyString(page) then
    page = "live"
end

local ifId = interface.getId()

local base_url = ntop.getHttpPrefix() .. "/lua/server_ports.lua"

page_utils.print_navbar(i18n('server_ports.server_ports'), base_url .. "?", {{
    hidden = not ntop.isEnterpriseL(),
    active = page == "flows_sankey",
    page_name = "flows_sankey",
    label = i18n("chart")
}, {
    active = page == "live",
    page_name = "live",
    label = i18n("jump_to_table")
}})

if (page == "live" or page == nil) then
    template.render("pages/server_ports.template", {
        ifid = ifId,
        draw = draw,
        sort = sort,
        order = order,
        start = start,
        length = length,
        is_live = true,
        csrf = ntop.getRandomCSRFValue()
    })
else
    local page_utils = require("page_utils")
    local json = require("dkjson")
    local template_utils = require("template_utils")
    local alerts_analysis_utils = require("alerts_analysis_utils")
    local ui_utils = require "ui_utils"

    local widget_gui_utils = require("widget_gui_utils")
    local ifid = interface.getId()
    local timeframe = tonumber(_GET["timeframe"])
    local vlan = tonumber(_GET["vlan"])
    local l4_proto = _GET["l4proto"]
    local page = _GET["page"]

    -- print the modes inside the dropdown
    local timeframe_options = {}
    local vlan_options = {}
    local l4_options = {}

    -- ####################

    local vlans = interface.getVLANsList()
    if (vlans ~= nil) then
        vlan_options[#vlan_options + 1] = {
            currently_active = (vlan == 'none' or vlan == nil),
            label = i18n('all'),
            key = 'none',
            id = 'none'
        }

        for _, v in pairs(vlans.VLANs) do
            local name = getFullVlanName(v.vlan_id)

            if isEmptyString(name) then
                name = i18n('no_vlan')
            end
            vlan_options[#vlan_options + 1] = {
                currently_active = (tonumber(vlan) == v.vlan_id),
                label = name,
                key = v.vlan_id,
                id = v.vlan_id
            }
        end
    end

    -- ####################

    if ntop.isClickHouseEnabled() then
        timeframe_options[#timeframe_options + 1] = {
            currently_active = (timeframe == 'none' or timeframe == nil),
            label = i18n("active_flows"),
            key = 'none',
            id = 'none'
        }

        for _, v in pairs(alerts_analysis_utils.timeframes_specs) do
            timeframe_options[#timeframe_options + 1] = {
                currently_active = (timeframe == v.duration),
                label = i18n("alerts_dashboard." .. v.label),
                key = v.duration,
                id = v.duration
            }
        end
    end

    -- ####################

    l4_options = {{
        currently_active = (l4_proto == "" or l4_proto == 'none' or l4_proto == nil),
        label = i18n("all_tcp_udp"),
        key = -1,
        id = -1
    }, {
        currently_active = (l4_proto == "TCP" or l4_proto == 'tcp' or l4_proto == 6),
        label = i18n("tcp"),
        key = l4_proto_to_id('TCP'),
        id = l4_proto_to_id('TCP')
    }, {
        currently_active = (l4_proto == "UDP" or l4_proto == 'udp' or l4_proto == 17),
        label = i18n("udp"),
        key = l4_proto_to_id('UDP'),
        id = l4_proto_to_id('UDP')
    }}

    -- ####################

    template_utils.render("pages/sankey_vlan.template", {
        widget_gui_utils = widget_gui_utils,
        ifid = ifid,
        ports_analysis = {
            timeframe_options = json.encode(timeframe_options),
            vlan_options = json.encode(vlan_options),
            l4_proto_options = json.encode(l4_options)
        }
    })

    print(ui_utils.render_notes({{
        content = i18n("server_ports.notes")
    }}))
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
