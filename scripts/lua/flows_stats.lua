--
-- (C) 2013-24 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ifstats = interface.getStats()

require "check_redis_prefs"
require "flow_utils"
require "lua_utils"
local page_utils = require("page_utils")
local template = require "template_utils"
local have_nedge = ntop.isnEdge()
local is_asn_mode_enabled = isASNModeEnabled()

sendHTTPContentTypeHeader('text/html')

local menu = ternary(have_nedge, page_utils.menu_entries.nedge_flows,
    page_utils.menu_entries.active_flows)

-- Select active entry in asn mode
if is_asn_mode_enabled then
    menu = page_utils.menu_entries.active_flows_asn_mode
end
page_utils.print_header_and_set_active_menu_entry(menu)



dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local draw = _GET["draw"] or 0
local sort = _GET["sort"] or "flows"
local order = _GET["order"] or "desc"
local start = _GET["start"] or 0
local length = _GET["length"] or 10
local page = _GET["page"]
local client = _GET["client"]
local server = _GET["server"]
local flow_info = _GET["flow_info"]
local aggregation_criteria = _GET["aggregation_criteria"] or "client_server_srv_port_app_proto"
local base_url = ntop.getHttpPrefix() .. "/lua/flows_stats.lua"
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
    interface.select(ifid)
end

local page_params = {
    ifid = interface.getId(),
    client = client,
    server = server,
    flow_info = flow_info
}

page_utils.print_navbar(i18n('graphs.active_flows'), base_url .. "?", {{
    active = page == "flows" or page == nil,
    url = base_url .. "?page=flows&traffic_type=unicast",
    page_name = "flows",
    label = "<i class=\"fas fa-lg fa-home\"></i>"
}, {
    url = base_url .. "?page=analysis&aggregation_criteria=" .. aggregation_criteria .. "&draw=" .. draw .. "&sort=" ..
        sort .. "&order=" .. order .. "&start=" .. start .. "&length=" .. length,
    active = page == "analysis",
    page_name = "analysis",
    label = i18n("aggregation")
}})

if (page == "flows" or page == nil) then
    local has_exporters = false
    if ntop.isPro() and interface.isPacketInterface() == false then
        local flowdevs = interface.getFlowDevices() or {}
        if table.len(flowdevs) > 0 then
            has_exporters = true
        end
    end

    local json = require "dkjson" 
    
    local json_context = json.encode({
        ifid = ifstats.id,
        has_exporters = has_exporters,
        is_viewed = interface.isViewed(),
        is_clickhouse_enabled = hasClickHouseSupport(),
        is_pcap = interface.isPcapDumpInterface(),
        csrf = ntop.getRandomCSRFValue(),
        is_enterprise_l = ntop.isEnterpriseL(),
        ASNModeEnabled = is_asn_mode_enabled,
        isNedge = have_nedge
    })
    template.render("pages/vue_page.template", { vue_page_name = "PageFlowsList", page_context = json_context })
else
    -- Analysis

    local json = require 'dkjson'
    -- Format VLANs dropdown
    local tmp_vlans = {}
    local vlans = {}
    local vlan_list = interface.getVLANsList() or {}

    if table.len(vlan_list) > 0 then
        vlan_list = vlan_list.VLANs
    end

    for _, vlan_info in pairsByField(vlan_list or {}, 'vlan_id', asc) do
        local label = i18n("hosts_stats.vlan_title", {
            vlan = getFullVlanName(vlan_info.vlan_id)
        })
        local currently_active = false

        if vlan_info.vlan_id == 0 then
            label = i18n('no_vlan')
        end

        tmp_vlans[#tmp_vlans + 1] = {
            label = label,
            id = vlan_info.vlan_id,
            countable = false,
            key = vlan_info.vlan_id,
            currently_active = (vlan == vlan_info.vlan_id or currently_active)
        }
    end
    if (#tmp_vlans > 1) then
        local currently_active = false

        tmp_vlans[#tmp_vlans + 1] = {
            label = i18n("flows_page.all_vlan_ids"),
            id = -1,
            countable = false,
            key = -1,
            currently_active = (vlan == -1 or currently_active)
        }
    end

    -- Order again by name
    for _, vlan in pairsByField(tmp_vlans or {}, 'label', asc_insensitive) do
        vlans[#vlans + 1] = vlan
    end

    local context = {
        ifid = ifstats.id,
        vlans = json.encode(vlans),
        aggregation_criteria = aggregation_criteria,
        is_ntop_enterprise_m = ntop.isEnterpriseM(),
        draw = draw,
        sort = sort,
        order = order,
        start = start,
        length = length,
        asn_mode = isASNModeEnabled(),
        host = "",
        csrf = ntop.getRandomCSRFValue()
    }

    local json_context = json.encode(context)
    template.render("pages/vue_page.template", { vue_page_name = "PageAggregatedLiveFlows", page_context = json_context })
 
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
