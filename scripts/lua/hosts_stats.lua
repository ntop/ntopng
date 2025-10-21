--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils_generic"
require "check_redis_prefs"
local vs_utils = require "vs_utils"

local host_pools_nedge
if ntop.isnEdge() then
    host_pools_nedge = require "host_pools_nedge"
end
local host_pools = require "host_pools"
-- Instantiate host pools
local host_pools_instance = host_pools:create()

local page_utils = require("page_utils")
local custom_column_utils = require("custom_column_utils")
local discover = require("discover_utils")
local template_utils = require("template_utils")
local have_nedge = ntop.isnEdge()
local wheel = nil

local host_ts_available = areHostTimeseriesEnabled()
local is_asn_mode_enabled = isASNModeEnabled()

local function generate_map_url(map, map_type, query, icon)
    local url = ""

    if (ntop.isPro()) then

        local map_available = table.len(map) > 0

        if (map_available) then
            url =
                "<a class='ms-1' href='" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/network_maps.lua?" .. query ..
                    "&map=" .. map_type .. "'><i class='" .. icon .. "'></i></a>"
        end
    end

    return url
end

sendHTTPContentTypeHeader('text/html')
local menu = page_utils.menu_entries.hosts

if is_asn_mode_enabled then
    menu = page_utils.menu_entries.hosts_asn_mode
end

page_utils.print_header_and_set_active_menu_entry(menu)
local protocol = _GET["protocol"]
local asn = _GET["asn"]
local vlan = _GET["vlan"]
local network = _GET["network"]
local cidr = _GET["network_cidr"]
local country = _GET["country"]
local mac = _GET["mac"]
local os_ = _GET["os"]
local community = _GET["community"]
local pool = _GET["pool"]
local ipversion = _GET["version"]
local traffic_type = _GET["traffic_type"]
local device_ip = _GET["deviceIP"]
local page = _GET["page"] or 'active_hosts'
local base_url = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua"
local page_params = {}
local charts_icon = ""

local mode = _GET["mode"]

if isEmptyString(mode) then
    mode = "all"
else
    page_params["mode"] = mode
end

local hosts_filter = ''

if ((mode ~= "all") or (not isEmptyString(pool))) then
    hosts_filter = '<span class="fas fa-filter"></span>'
end

function getPageTitle(protocol_name, traffic_type_title, device_ip_title, network_name, cidr, ipver_title, os_, country,
    asninfo, mac, pool_, vlan_title, vlan_alias)
    local mode_label = ""

    if mode == "remote" then
        mode_label = i18n("hosts_stats.remote")
    elseif mode == "remote_no_tx" then
        mode_label = i18n("hosts_stats.remote_no_tx")
    elseif mode == "remote_no_tcp_tx" then
        mode_label = i18n("hosts_stats.remote_no_tcp_tx")
    elseif mode == "local" then
        mode_label = i18n("hosts_stats.local")
    elseif mode == "local_no_tx" then
        mode_label = i18n("hosts_stats.local_no_tx")
    elseif mode == "local_no_tcp_tx" then
        mode_label = i18n("hosts_stats.local_no_tcp_tx")
    elseif mode == "filtered" then
        mode_label = i18n("hosts_stats.filtered")
    elseif mode == "blacklisted" then
        mode_label = i18n("hosts_stats.blacklisted")
    elseif mode == "dhcp" then
        mode_label = i18n("nedge.network_conf_dhcp")
    elseif mode == "broadcast_multicast" then
       mode_label = i18n("hosts_stats.broadcast_and_multicast")
    end

    if (network == nil) then
        wheel = ""
        charts_icon = ""
    else
        wheel =
            '<A HREF="' .. ntop.getHttpPrefix() .. '/lua/network_details.lua?network=' .. network .. '&page=config' ..
                '"><i class="fas fa-cog fa-sm"></i></A>'
        charts_icon =
            charts_icon .. "&nbsp; <a href='" .. ntop.getHttpPrefix() .. "/lua/network_details.lua?network=" .. network ..
                "&page=historical'><i class='fas fa-sm fa-chart-area'></i></a>"
    end

    -- Note: we must use the empty string as fallback. Multiple spaces will be collapsed into one automatically.
    return i18n("hosts_stats.hosts_page_title", {
        all = isEmptyString(mode_label) and i18n("hosts_stats.all") or "",
        traffic_type = traffic_type_title or "",
        device_ip = device_ip_title or "",
        local_remote = mode_label,
        protocol = protocol_name or "",
        network = not isEmptyString(network_name) and i18n("hosts_stats.in_network", {
            network = network_name
        }) or "",
        network_cidr = not isEmptyString(cidr) and i18n("hosts_stats.in_network", {
            network = cidr
        }) or "",
        ip_version = ipver_title or "",
        ["os"] = discover.getOsName(os_),
        country_asn_or_mac = country or asninfo or mac or pool_ or "",
        vlan = vlan_title or "",
        vlan_name = vlan_alias or "",
        charts_icon = charts_icon,
        wheel = wheel
    })
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local ifstats = interface.getStats()

-- Parameters necessary for the page title
local protocol_name = nil
local network_name = nil
local traffic_type_title = nil
local device_ip_title = nil
local ipver_title = nil
local asninfo = nil
local os_title = nil
local country_title = nil
local mac_title = nil
local vlan_title = nil
local pool_title = nil
local vlan_alias = nil

if ((protocol ~= nil) and (protocol ~= "")) then
    protocol_name = interface.getnDPIProtoName(tonumber(protocol))
end

if (protocol_name == nil) then
    protocol_name = protocol
end

if not isEmptyString(traffic_type) then
    page_params["traffic_type"] = traffic_type

    if traffic_type == "one_way" then
        traffic_type_title = i18n("hosts_stats.traffic_type_one_way")
    elseif traffic_type == "bidirectional" then
        traffic_type_title = i18n("hosts_stats.traffic_type_two_ways")
    end
else
    traffic_type_title = ""
end

if not isEmptyString(device_ip) then
    page_params["deviceIP"] = device_ip

    device_ip_title = i18n("hosts_stats.probe_traffic", {
        device_ip = device_ip
    })
end

if (tonumber(network) ~= nil) then
    network_name = getLocalNetworkAlias(tonumber(network))

    if isEmptyString(network_name) then
        network_name = i18n("hosts_stats.remote")
    end
else
    network_name = ""
end

if not isEmptyString(ipversion) then
    ipver_title = i18n("hosts_stats.ipver_title", {
        version_num = ipversion
    })
else
    ipver_title = ""
end

if (asn ~= nil) then
    asninfo = " " .. i18n("hosts_stats.asn_title", {
        asn = asn
    }) ..
                  "<small>&nbsp;<i class='fas fa-info-circle fa-sm' aria-hidden='true'></i> <A class='ntopng-external-link' href='https://stat.ripe.net/AS" ..
                  asn .. "'><i class='fas fa-external-link-alt fa-sm' title=\\\"" ..
                  i18n("hosts_stats.more_info_about_as_popup_msg") .. "\\\"></i></A> " .. charts_icon ..
                  "&nbsp; <a href='" .. ntop.getHttpPrefix() .. "/lua/as_details.lua?asn=" .. asn ..
                  "&page=historical'><i class='fas fa-sm fa-chart-area'></i></a> </small>"
end

if (os_ ~= nil) then
    os_title = " " .. os_
end

if (country ~= nil and country ~= '') then
    country_title = " " .. i18n("hosts_stats.country_title", {
        country = country
    })
end

if (mac ~= nil and mac ~= '') then
    mac_title = " " .. i18n("hosts_stats.mac_title", {
        mac = mac
    })
end

if (vlan ~= nil and vlan ~= '') then

    local link_service_map = generate_map_url(interface.serviceMap(nil, tonumber(vlan)), "service_map", "vlan=" .. vlan,
        "fas fa-concierge-bell")
    local link_periodicity_map = generate_map_url(interface.periodicityMap(nil, tonumber(vlan)), "periodicity_map",
        "vlan=" .. vlan, "fas fa-clock")

    local vlan_label = i18n('untagged')
    if (vlan ~= 0 and vlan ~= '0') then
        vlan_label = i18n("hosts_stats.vlan_title", {
            vlan = vlan
        })
    end
    vlan_title = " [" .. vlan_label .. "]"
    local config_button = " <A HREF='" .. ntop.getHttpPrefix() .. "/lua/vlan_details.lua?vlan=" .. vlan .. "&page=config" ..
                     "'><i class='fas fa-cog fa-sm'></i></A>"

    -- in case of untagged traffic is not possible to set a vlan alias
    if (vlan ~= 0 and vlan ~= '0') then
        vlan_title = vlan_title .. config_button
    end

    vlan_title = vlan_title .. " " .. link_service_map .. " " .. link_periodicity_map
    if (vlan == getVlanAlias(vlan)) then
        vlan_alias = ""
    else
        vlan_alias = getVlanAlias(vlan)
    end
end

if (pool ~= nil and pool ~= '') then
    local link_service_map = ""
    local link_periodicity_map = ""
    local charts_available = areHostPoolsTimeseriesEnabled(ifstats.id)

    if (tonumber(pool) ~= host_pools_instance.DEFAULT_POOL_ID) then
        link_service_map = generate_map_url(interface.serviceMap(nil, nil, tonumber(pool)), "service_map",
            "host_pool_id=" .. pool, "fas fa-concierge-bell")
        link_periodicity_map = generate_map_url(interface.periodicityMap(nil, nil, tonumber(pool)), "periodicity_map",
            "host_pool_id=" .. pool, "fas fa-clock")
    end

    local pool_edit = ""
    local pool_link
    local title

    if (tonumber(pool) ~= host_pools_instance.DEFAULT_POOL_ID) or (have_nedge) then
        if have_nedge then
            pool_link = "/lua/pro/nedge/admin/nf_edit_user.lua?username=" ..
                            ternary(tonumber(pool) == host_pools_nedge.DEFAULT_POOL_ID, "",
                    host_pools_nedge.poolIdToUsername(pool))
            title = i18n("nedge.edit_user")
        else
            pool_link = "/lua/admin/manage_host_members.lua?pool=" .. pool
            title = i18n("host_pools.manage_pools")
        end

        pool_edit =
            "&nbsp; <A HREF='" .. ntop.getHttpPrefix() .. pool_link .. "'><i class='fas fa-cog fa-sm' title='" .. title ..
                "'></i></A>"
    end

    pool_title = " " .. i18n(ternary(have_nedge, "hosts_stats.user_title", "hosts_stats.pool_title"), {
        poolname = host_pools_instance:get_pool_name(pool)
    }) .. "<small>" .. pool_edit .. ternary(charts_available,
        " <a href='" .. ntop.getHttpPrefix() .. "/lua/pool_details.lua?page=historical&pool=" .. pool ..
            "'><i class='fas fa-chart-area fa-sm' title='" .. i18n("chart") .. "'></i></a>", "") .. link_service_map ..
                     link_periodicity_map .. "</small>"
end

page_utils.print_navbar(i18n("hosts"), base_url .. "?", {{
    active = page == "active_hosts" or page == nil,
    page_name = "active_hosts",
    label = i18n('active_hosts')
}, {
    hidden = not host_ts_available or not ntop.isEnterpriseXL() or is_asn_mode_enabled,
    active = page == "local_hosts_report",
    page_name = "local_hosts_report",
    label = i18n("local_hosts_report")
}, {
    hidden = not areASTimeseriesEnabled(ifid) or not asn,
    active = page == "exporters_stats",
    page_name = "exporters_stats",
    label = i18n("as_info"),
    url = ntop.getHttpPrefix() .. "/lua/as_overview.lua?asn=" .. (asn or 0)
}})

if page == "active_hosts" then
    local json = require "dkjson" 
    local vlans = interface.getVLANsList()
    local json_context = json.encode({
        ifid = ifstats.id,
        has_vlans = (vlans ~= nil),
        csrf = ntop.getRandomCSRFValue(),
        isNedge = have_nedge
    })
    template_utils.render("pages/vue_page.template", { vue_page_name = "PageHostsList", page_context = json_context })
elseif page == "local_hosts_report" then
    local json = require "dkjson"
    local json_context = json.encode({
        ifid = ifstats.id,
        csrf = ntop.getRandomCSRFValue()
    })
    template_utils.render("pages/vue_page.template", { vue_page_name = "PageLocalHostsReport", page_context = json_context })
    
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
