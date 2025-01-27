
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local snmp_utils
local snmp_location
local host_sites_update
local sites_granularities = {}
local auth = require "auth"
local ts_utils = require "ts_utils_core"


local vs_utils = require "vs_utils"
local cve_utils = require "cve_utils"

if (ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    snmp_utils = require "snmp_utils"
    snmp_location = require "snmp_location"
    shaper_utils = require("shaper_utils")
    host_sites_update = require("host_sites_update")
end

require "lua_utils"
local graph_utils = require "graph_utils"
local json = require("dkjson")
local discover = require "discover_utils"
local ui_utils = require "ui_utils"
local page_utils = require "page_utils"
local template = require "template_utils"
local fingerprint_utils = require "fingerprint_utils"
local am_utils = require "am_utils"
local behavior_utils = require "behavior_utils"

local host_pools_nedge
if ntop.isnEdge() then
    host_pools_nedge = require "host_pools_nedge"
end
local host_pools = require "host_pools"
-- Instantiate host pools
local host_pools_instance = host_pools:create()

local info = ntop.getInfo()

local have_nedge = ntop.isnEdge()

local debug_hosts = false

local page = _GET["page"]
local host_info = url2hostinfo(_GET)
local host_ip = host_info["host"]
local host_vlan = host_info["vlan"] or 0
local format_utils = require("format_utils")

if not isEmptyString(_GET["ifid"]) then
    interface.select(_GET["ifid"])
else
    interface.select(ifname)
end

local ifstats = interface.getStats()

ifId = ifstats.id

local charts_available = areHostTimeseriesEnabled(ifId, host_info)

local is_pcap_dump = interface.isPcapDumpInterface()

local host = nil
local family = nil

local prefs = ntop.getPrefs()

local hostkey = hostinfo2hostkey(host_info, nil, true --[[ force show vlan --]] )
local hostkey_compact = hostinfo2hostkey(host_info) -- do not force vlan
 
if not host_ip then
    sendHTTPContentTypeHeader('text/html')

    page_utils.print_header()
    dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
    print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " ..
            i18n("host_details.host_parameter_missing_message") .. "</div>")
    dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
    return
end

-- print(">>>") print(host_info["host"]) print("<<<")
if (debug_hosts) then
    traceError(TRACE_DEBUG, TRACE_CONSOLE, i18n("host_details.trace_debug_host_info", {
        hostinfo = host_info["host"],
        vlan = host_vlan
    }) .. "\n")
end
local host = interface.getHostInfo(host_info["host"], host_vlan)
local tskey

if _GET["tskey"] then
    tskey = _GET["tskey"]
elseif host then
    tskey = host["tskey"]
else
    tskey = host_key
end

local restoreFailed = false
local restoreInProgress = false

-- #####################################################

local function takeHistoricalBaseUrl(port)
    local extra_params = {
        srv_ip = {
            value = host_ip,
            operator = "eq"
        },
        srv_port = {
            value = port,
            operator = "eq"
        }
    }
    if host_vlan ~= 0 then
        extra_params.vlan_id = {
            value = host_vlan,
            operator = "eq"
        }
    end

    return add_historical_flow_explorer_button_ref(extra_params, true)
end

-- #####################################################

local function printPort(port, proto, is_server_port)
    if is_server_port then
        local historical_base_url = takeHistoricalBaseUrl(port)

        if (historical_base_url and (historical_base_url ~= "")) then
            print('<li><A HREF="' .. historical_base_url .. '"><span class="badge bg-secondary">' .. port .. " (" ..
                      proto .. ")" .. "</span></A></li>\n")
        else
            print('<li><A HREF="' .. ntop.getHttpPrefix() .. '/lua/flows_stats.lua?port=' .. port .. '"><span class="badge bg-secondary">' .. port ..
                      " (" .. proto .. ")" .. "</span></A></li>\n")
        end
    else
        print(
            '<li><A HREF="' .. ntop.getHttpPrefix() .. '/lua/flows_stats.lua?port=' .. port .. '"><span class="badge bg-secondary">' .. port .. " (" ..
                proto .. ")" .. "</span></A></li>\n")
    end
end

-- #####################################################

local function printPorts(ports, is_server_port)
    if (table.len(ports) == 0) then
        print("<td colspan=2>" .. i18n("none") .. "</td></tr>")
    else
        local udp = {}
        local tcp = {}
        print("<th>UDP</th><th>TCP</th></tr>\n")

        for k, v in pairs(ports) do
            local res = split(k, ":")

            if tonumber(res[2]) then
                if (res[1] == "udp") then
                    udp[tonumber(res[2])] = v
                else
                    tcp[tonumber(res[2])] = v
                end
            end
        end

        print("<tr><td valign=top><ul>")
        for port, proto in pairsByKeys(udp) do
            printPort(port, proto, is_server_port)
        end

        print("</ul></td><td valign=top><ul>")
        for port, proto in pairsByKeys(tcp) do
            printPort(port, proto, is_server_port)
        end
        print("</td></tr>\n")
    end
end

-- #####################################################

local function formatContacts(v)
    if not v then
        return ""
    end

    if (v > 5) then
        return ("<font color=red><b>" .. formatValue(v) .. "</b></font>")
    else
        return (formatValue(v))
    end
end

-- #####################################################

local function scoreBreakdown(what)
    local score_category_network = what[0]
    local score_category_security = what[1]
    local tot = score_category_network + score_category_security

    if (tot > 0) then
        score_category_network = (score_category_network * 100) / tot
        score_category_security = 100 - score_category_network

        print('<span class="progress w-100 ms-1"><span class="progress-bar bg-warning" style="width: ' ..
                  score_category_network .. '%;">' .. i18n("flow_details.score_category_network"))
        print('</span><span class="progress-bar bg-success" style="width: ' .. score_category_security .. '%;">' ..
                  i18n("flow_details.score_category_security") .. '</span></span>\n')
    else
        print("&nbsp;")
    end
end

-- #####################################################

local function printRestoreHostBanner(hidden)
    print('<div id=\"host_purged\" class=\"alert alert-danger\" ')
    if hidden then
        print('style=\"display:none;\"')
    end
    print('><i class="fas fa-exclamation-triangle"></i>')
    print [[<form class="form-inline" id="host_restore_form" method="get">]]
    print [[<input type="hidden" name="mode" value="restore">
   <input type="hidden" name="host" value="]]
    print(host_info["host"])
    print [[">]]
    if ((host_info["vlan"] ~= nil) and ifstats.vlan) then
        print [[<input type="hidden" name="vlan" value="]]
        print(tostring(host_info["vlan"]))
        print [[">]]
    end
    print [[</form>]]
    print [[ ]]
    print(i18n("host_details.restore_from_cache_message_v1", {
        host = hostinfo2hostkey(host_info),
        js_code = "\"javascript:void(0);\" onclick=\"$(\'#host_restore_form\').submit();\""
    }))
    print("</div>")
end

local host_pool_id = nil

if (host ~= nil) then
    charts_available = charts_available and host["localhost"] and not host["is_multicast"]
    if (host_pool_id == nil) then
        host_pool_id = tostring(host["host_pool_id"])
    end
end

local only_historical = (host == nil) and ((page == "historical") or (page == "config"))
local host_label

if (host == nil) and (not only_historical) then
    -- We need to check if this is an aggregated host
    sendHTTPContentTypeHeader('text/html')

    page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.hosts)
    if restoreInProgress then
        dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
        print('<div class=\"alert alert-info\"> ' .. i18n("host_details.host_restore_in_progress", {
            host = hostinfo2hostkey(host_info)
        }) .. " ")
        print('<i class="fas fa-spinner fa-spin"></i>')
        print("</div>")
        print [[<script type='text/javascript'>
   let recheckInterval = null;

   function recheckHostRestore() {
      $.ajax({
        type: 'GET',
        url: ']]
        print(ntop.getHttpPrefix())
        print [[/lua/host_stats.lua',
        data: { ifid: "]]
        print(ifId .. "")
        print('", ' .. hostinfo2json(host_info))
        print [[ },
        success: function(content) {
         if(content && content != '"{}"') {
            /* Host found, reload the page */
            clearInterval(recheckInterval);
            recheckInterval = null;
            location.reload();
         }
        }
      });
   }

   recheckInterval = setInterval(recheckHostRestore, 2000);
   recheckHostRestore();
</script>]]
        dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
    else
        dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
        if (not (restoreFailed) and (host_info ~= nil) and canRestoreHost(ifId, host_info["host"], host_vlan)) then
            printRestoreHostBanner()
        else
            print('<div class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle"></i> ')
            print(i18n("host_details.host_cannot_be_found_message", {
                host = hostinfo2hostkey(host_info)
            }) .. " ")
            print(purgedErrorString())
            print("</div>")
        end

        dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
        return
    end
else
    sendHTTPContentTypeHeader('text/html')

    page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.hosts, nil, i18n("host", {
        host = host_info["host"]
    }))

    dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

    --   Added global javascript variable, in order to disable the refresh of pie chart in case
    --  of historical interface
    print('\n<script>var refresh = 3000 /* ms */;</script>\n')

    if _POST["action"] == "reset_stats" and isAdministrator() then
        if _POST["resetstats_mode"] == "reset_blacklisted" then
            interface.resetHostStats(hostkey, true)
        elseif interface.resetHostStats(hostkey) then
            print("<div class=\"alert alert alert-success\">")
            print(i18n("host_details.reset_stats_in_progress"))
            print [[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
            print("</div>")
        end
    end

    if host == nil then
        -- only_historical = true here
        host = hostkey2hostinfo(host_info["host"] .. "@" .. host_vlan)
    end

    host_label = hostinfo2label(host, false, false)
-- tprint(host.names)
    if canRestoreHost(ifId, host_info["host"], host_vlan) then
        printRestoreHostBanner(true --[[ hidden ]] )
    else
        print(
            '<div style=\"display:none;\" id=\"host_purged\" class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle"></i>&nbsp;' ..
                i18n("details.host_purged") .. '</div>')
    end

    local title = i18n("host_details.host") .. ": " .. shortenString(host_label)
    if host["broadcast_domain_host"] then
        title = title .. " &nbsp;<i class='fas fa-sitemap' aria-hidden='true' title='" ..
                    i18n("hosts_stats.label_broadcast_domain_host") .. "'></i>"
    end

    local url = hostinfo2detailsurl(host, {
        tskey = _GET["tskey"]
    })

    if (ntop.isPro()) then
        sites_granularities = host_sites_update.getGranularitySites(host_ip, host_vlan, ifId, false)
    end
    
    local has_snmp_location = snmp_location and snmp_location.host_has_snmp_location(host["mac"])
    local has_icmp = ((table.len(host["ICMPv4"]) + table.len(host["ICMPv6"])) ~= 0)
    local has_assets = ntop.isEnterpriseXL() and (host.asset_key ~= nil) and
                           (ntop.getHashKeysCache(host.asset_key) ~= nil)
    local periodicity_map_available = false
    local service_map_available = false
    local num_periodicity = 0

    local service_map_link = ntop.getHttpPrefix() .. "/lua/pro/enterprise/network_maps.lua?map=service_map&ifid=" ..
                                 ifId .. "&host=" .. host_ip
    local periodicity_map_link = ntop.getHttpPrefix() ..
                                     "/lua/pro/enterprise/network_maps.lua?map=periodicity_map&ifid=" .. ifId ..
                                     "&host=" .. host_ip
    local historical_flow_link = ntop.getHttpPrefix() .. "/lua/db_search.lua?ifid=" .. ifId .. "&ip=" .. host_ip .. ";eq"

    service_map_available, periodicity_map_available = behavior_utils.mapsAvailable()

    if (host_vlan ~= 0) then
        historical_flow_link = historical_flow_link .. "&vlan_id=" .. host_vlan .. ";eq"
    end

    if (service_map_available) and (host_vlan ~= 0) then
        service_map_link = service_map_link .. "&vlan_id=" .. host_vlan
    end

    if (periodicity_map_available) and (host_vlan ~= 0) then
        periodicity_map_link = periodicity_map_link .. "&vlan_id=" .. host_vlan
    end

    local total_packets_data = 0
    if host then
        if host["pktStats.sent"] then
            for _, value in pairs(host["pktStats.sent"]["size"] or {}) do
                total_packets_data = total_packets_data + value
            end

            for _, value in pairs(host["pktStats.recv"]["size"] or {}) do
                total_packets_data = total_packets_data + value
            end
        end

        if host["pktStats.recv"] then
            for _, value in pairs(host["pktStats.sent"]["tcp_flags"] or {}) do
                total_packets_data = total_packets_data + value
            end

            for _, value in pairs(host["pktStats.recv"]["tcp_flags"] or {}) do
                total_packets_data = total_packets_data + value
            end
        end

        local eth_stats = interface.getMacInfo(host["mac"])

        if eth_stats then
            total_packets_data = total_packets_data + eth_stats["arp_requests.sent"] + eth_stats["arp_replies.sent"]
            total_packets_data = total_packets_data + eth_stats["arp_requests.rcvd"] + eth_stats["arp_replies.rcvd"]
        end
    end

    local ifs = interface.getStats()

    page_utils.print_navbar(title, url, {{
        hidden = only_historical,
        active = page == "overview" or page == nil,
        page_name = "overview",
        label = "<i class=\"fas fa-lg fa-home\"></i>"
    }, {
        hidden = only_historical,
        active = page == "traffic",
        page_name = "traffic",
        label = i18n("traffic")
    }, {
        hidden = have_nedge or host["is_broadcast"] or host["is_multicast"] or only_historical or
            (total_packets_data == 0),
        active = page == "packets",
        page_name = "packets",
        label = i18n("packets")
    }, {
        hidden = only_historical,
        active = page == "ports",
        page_name = "ports",
        label = i18n("ports")
    }, {
        hidden = only_historical or interface.isLoopback(),
        active = page == "peers",
        page_name = "peers",
        label = i18n("peers")
    }, {
        hidden = have_nedge or only_historical or not (has_icmp),
        active = page == "ICMP",
        page_name = "ICMP",
        label = i18n("icmp")
    }, {
        hidden = only_historical,
        active = page == "ndpi",
        page_name = "ndpi",
        label = i18n("applications")
    }, {
        hidden = have_nedge or only_historical or not host["localhost"],
        active = page == "dns",
        page_name = "dns",
        label = i18n("dns")
    }, {
        hidden = have_nedge or only_historical or not fingerprint_utils.has_fingerprint_stats(host, "ja4"),
        active = page == "tls",
        page_name = "tls",
        label = i18n("tls")
    }, {
        hidden = have_nedge or only_historical or not fingerprint_utils.has_fingerprint_stats(host, "hassh"),
        active = page == "ssh",
        page_name = "ssh",
        label = i18n("ssh")
    }, {
        hidden = only_historical or have_nedge or not host["localhost"] or not host["http"] or
            (host["http"]["sender"]["query"]["total"] == 0 and host["http"]["receiver"]["response"]["total"] == 0 and
                table.len(host["http"]["virtual_hosts"] or {}) == 0),
        active = page == "http",
        page_name = "http",
        label = i18n("http"),
        badge_num = host["active_http_hosts"]
    }, {
        hidden = only_historical or not host["localhost"] or (table.len(sites_granularities) == 0),
        active = page == "sites",
        page_name = "sites",
        label = i18n("sites_page.sites")
    }, {
        hidden = not has_snmp_location,
        active = page == "snmp",
        page_name = "snmp",
        label = i18n("host_details.snmp")
    }, {
        hidden = only_historical or not interface.hasEBPF(), -- or not host["systemhost"]
        active = page == "processes",
        page_name = "processes",
        label = i18n("user_info.processes")
    }, {
        hidden = have_nedge or only_historical or not host.listening_ports or table.len(host.listening_ports) == 0,
        active = page == "listening_ports",
        page_name = "listening_ports",
        label = "<i class='fas fa-lg fa-headphones' title='" .. i18n("listening_ports") .. "'></i>"
    }, {
        hidden = only_historical,
        active = page == "flows",
        page_name = "flows",
        label = '<i class="fas fa-stream" title="' .. i18n("active_flows") .. '"></i>'
    }, {
        hidden = only_historical or not ntop.isEnterpriseL(),
        active = page == "flows_sankey",
        page_name = "flows_sankey",
        label = '<i class="fas fa-draw-polygon" title="' .. i18n("host_flows") .. '"></i>'
    }, {
        hidden = only_historical or host["is_broadcast"] or host["is_multicast"] or not ntop.hasGeoIP(),
        active = page == "geomap",
        page_name = "geomap",
        label = "<i class='fas fa-lg fa-globe' title='" .. i18n("geo_map.geo_map") .. "'></i>"
    }, {
        hidden = not areAlertsEnabled() or not auth.has_capability(auth.capabilities.alerts),
        active = page == "alerts",
        page_name = "alerts",
        label = "<i class='fas fa-lg fa-exclamation-triangle' title='" .. i18n("alerts_dashboard.alerts") .. "'></i>",
        url = hostinfo2detailsurl(host, {
            page = ternary((host.num_alerts or 0) > 0, "engaged-alerts", "alerts")
        })
    }, {
        hidden = not has_assets,
        active = page == "assets",
        page_name = "assets",
        label = "<i class='fas fa-lg fa-compass' title='" .. i18n("assets") .. "'></i>"
    }, {
        hidden = not charts_available,
        active = page == "historical",
        page_name = "historical",
        label = "<i class='fas fa-lg fa-chart-area' title='" .. i18n("historical") .. "'></i>"
    }, {
        hidden = only_historical or (not host["localhost"]) or (not hasTrafficReport()),
        active = page == "traffic_report",
        page_name = "traffic_report",
        label = "<i class='fas fa-lg fa-file-alt report-icon' title='" .. i18n("report.traffic_report") .. "'></i>"
    }, {
        hidden = only_historical or not ntop.isEnterpriseM() or not ifstats.inline or not host_pool_id ~=
            host_pools_instance.DEFAULT_POOL_ID,
        active = page == "quotas",
        page_name = "quotas",
        label = i18n("quotas")
    }, {
        hidden = not periodicity_map_available,
        active = page == "periodicity_map",
        page_name = "periodicity_map",
        url = periodicity_map_link,
        label = "<i class=\"fas fa-lg fa-clock\" title='" .. i18n("periodicity_map") .. "'></i>",
        badge_num = num_periodicity
    }, {
        hidden = not service_map_available,
        active = page == "service_map",
        page_name = "service_map",
        label = "<i class=\"fas fa-lg fa-concierge-bell\" title='" .. i18n("service_map") .. "'\"></i>",
        url = service_map_link
    }, {
        hidden = not ntop.isClickHouseEnabled() or page == "historical",
        active = page == "db_search",
        page_name = "db_search",
        label = "<i class=\"fas fa-search-plus\" title='" .. i18n("db_explorer.historical_data_explorer") .. "'\"></i>",
        url = historical_flow_link
    }, {
        hidden = not isAdministrator() or interface.isPcapDumpInterface(),
        active = page == "config",
        page_name = "config",
        label = "<i class='fas fa-lg fa-cog' title='" .. i18n("settings") .. "'></i></a></li>"
    }})

    if(((host["bytes.sent"] == 0) or (host["bytes.rcvd"] == 0)) and host["localhost"] and not host["is_multicast"] and not host["is_broadcast"]) then
      print("<div class=\"alert alert alert-warning\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("host_details.unidirectional_traffic") .. "</div>")
    end

    if(host.inconsistent_host_os) then
       print("<div class=\"alert alert alert-warning\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " .. i18n("host_details.inconsistent_host_os") .. "</div>")
    end
    
    -- tprint(host.bins)
    local macinfo = interface.getMacInfo(host["mac"])
    local has_snmp_location = host['localhost'] and (host["mac"] ~= "") and snmp_location and
                                  snmp_location.host_has_snmp_location(host["mac"]) and isAllowedSystemInterface()

    if ((page == "overview") or (page == nil)) then
        print [[
  <div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="mt-4 card card-shadow">
      <div class="card-body">
      ]]
        print("<table class=\"table table-striped table-bordered\">\n")
        if (host["ip"] ~= nil) then
            if (host["mac"] ~= "00:00:00:00:00:00") then
                if (host.router ~= nil) then
                    print("<tr><th width=35%>" .. i18n("details.router_access_point_mac_address") ..
                              "</th><td colspan=2>" .. get_symbolic_mac(host.router, false) .. " </td></tr>")
                    print("<tr><th width=35%>" .. i18n("details.host_mac_address") .. "</th><td>" ..
                              get_symbolic_mac(host["mac"], false) .. " " .. discover.devtype2icon(host["device_type"]))
                else
                    if (host.localhost) then
                        print("<tr><th width=35%>" .. i18n("details.mac_address") .. "</th><td>" ..
                                  get_symbolic_mac(host["mac"], false) .. " " ..
                                  discover.devtype2icon(host["device_type"]))
                    else
                        print("<tr><th width=35%>" .. i18n("details.router_access_point_mac_address") .. "</th><td>" ..
                                  get_symbolic_mac(host["mac"], false) .. " " ..
                                  discover.devtype2icon(host["device_type"]))
                    end

		    printInterfaceIndex(host.iface_index)
                end
                print('</td><td>')

                if (host['localhost'] and (macinfo ~= nil)) then
                    -- This is a known device type
                    print(discover.devtype2icon(macinfo.devtype) .. " ")
                    if macinfo.devtype ~= 0 then
                        print(discover.devtype2string(macinfo.devtype) .. " ")
                    else
                        print(i18n("host_details.unknown_device_type") .. " ")
                    end
                    print('<a href="' .. ntop.getHttpPrefix() .. '/lua/mac_details.lua?' .. hostinfo2url(macinfo) ..
                              '&page=config"><i class="fas fa-cog"></i></a>\n')
                else
                    print("&nbsp;")
                end

                print('</td></tr>')
            end

            if has_snmp_location then
                snmp_location.print_host_snmp_location(host["mac"], hostinfo2detailsurl(host, {
                    page = "snmp"
                }))
            end

            print("</tr>")

            print("<tr><th>" .. i18n("ip_address") .. "</th><td colspan=1>" .. host["ip"])
            if (host.childSafe == true) then
                print(getSafeChildIcon())
            end

            if (host.os ~= 0) then
                print(" " .. discover.getOsIcon(host.os) .. " ")
            end

            if (host["local_network_name"] ~= nil) then
                local network_name = getLocalNetworkAlias(host["local_network_name"])

                if ((network_name == nil) or (network_name == "") or (network_name == host["local_network_name"])) then
                    network_name = ""
                else
                    network_name = " (" .. network_name .. ")"
                end

                print(" [&nbsp;<A HREF='" .. ntop.getHttpPrefix() .. "/lua/network_details.lua?network=" ..
                          host["local_network_id"] .. "&page=historical'>" .. host["local_network_name"] .. "</A> " ..
                          network_name .. " &nbsp;]")
            end

            if ((host["city"] ~= nil) and (host["city"] ~= "")) then
                print(" [ " .. host["city"] .. " " .. getFlag(host["country"]) .. " ]")
            end

            print [[</td><td><span>]]
            print(i18n(ternary(have_nedge, "nedge.user", "details.host_pool")) .. ": ")
            print [[<a href="]]
            print(ntop.getHttpPrefix())
            print [[/lua/hosts_stats.lua?pool=]]
            print(host_pool_id)
            print [[">]]
            print(host_pools_instance:get_pool_name(host_pool_id))
            print [[</a></span>]]
            print [[&nbsp;]]
            print(hostinfo2detailshref(host, {
                page = "config"
            }, '<i class="fas fa-cog" aria-hidden="true"></i>'))
            print("</td></tr>")
        else
            if (host["mac"] ~= nil) then
                print("<tr><th>" .. i18n("mac_address") .. "</th><td colspan=2>" .. host["mac"] .. "</td></tr>\n")
            end
        end

        if host["vlan"] and host["vlan"] > 0 then
            print("<tr><th>")
            print(i18n("details.vlan_id"))
            print(
                "</th><td colspan=2><A HREF=" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?vlan=" .. host["vlan"] ..
                    ">" .. getFullVlanName(host["vlan"]) .. "</A></td></tr>\n")
        end

        if (host["os"] ~= "" and host["os"] ~= 0) then
            print("<tr>")
            if (host["os"] ~= "") then
                local os_detail = ""

		if not isEmptyString(host["os_detail"]) then
		   os_detail = os_detail .. " [ " .. host["os_detail"] .. " ]"
                end
		
                print("<th>" .. i18n("os") .. "</th><td> <A HREF='" .. ntop.getHttpPrefix() ..
		      "/lua/hosts_stats.lua?os=" .. host["os"] .. "'>" .. discover.getOsAndIcon(host["os"]) ..
		      "</A>" .. os_detail)

		if(false) then
		   if(host["tcp_fingerprint"] ~= nil) then
		      print(" <span class=\"badge bg-success\">TCP Fingerprint: "..host["tcp_fingerprint"].. "</span>")
		   end
		end
		
		print("</td><td></td>\n")
            else
                print("<th></th><td></td>\n")
            end
            print("</tr>")
        end

        if ((host["asn"] ~= nil) and (host["asn"] > 0)) then
            print("<tr><th>" .. i18n("asn") .. "</th><td>")

            print(
                "<A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" .. host.asn .. "'>" .. host.asname ..
                    "</A> [ " .. i18n("asn") .. " <A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=" ..
                    host.asn .. "'>" .. host.asn .. "</A> ]</td>")
            print('<td><A class="ntopng-external-link" href="http://itools.com/tool/arin-whois-domain-search?q=' ..
                      host["ip"] .. '&submit=Look+up">' .. i18n("details.whois_lookup") ..
                      ' <i class="fas fa-external-link-alt"></i></A> <A class="ntopng-external-link" href="https://stat.ripe.net/' ..
                      host["ip"] .. '">' .. i18n("details.ripestat_lookup") ..
                      ' <i class="fas fa-external-link-alt"></i></A></td>')
            print("</td></tr>\n")
        end

        if ((host["observation_point_id"] ~= nil) and (host["observation_point_id"] ~= 0)) then
            print("<tr><th>" .. i18n("details.observation_point_id") .. "</th>")
            print("<td colspan=\"2\">" .. host["observation_point_id"] .. "</td></tr>")
        end

        if (host["ip"] ~= nil) then
            print("<tr><th>" .. i18n("name") .. "</th>")

            if (isAdministrator()) then
                local n = hostinfo2label(host, true)
                print("<td colspan=2><A class='ntopng-external-link' href=\"http://" .. n ..
                          "\"> <span id=name>")
            else
                print("<td colspan=2>")
            end

            if ntop.shouldResolveHost(host["ip"]) then
                print(
                    '<div id="throbber" class="spinner-border spinner-border-sm text-primary" role="status"><span class="sr-only">Loading...</span></div> ')
            end

            print(host_label .. "</span> <i class=\"fas fa-external-link-alt\"></i> </A>")

            print(hostinfo2detailshref(host, {
                page = "config"
            }, ' <i class="fas fa-sm fa-cog" aria-hidden="true"></i> '))

            print(format_utils.formatFullAddressCategory(host))

            if (host.services) then
                if (host.services.dhcp) then
                    print(' <span class="badge bg-success">' .. i18n("details.label_dhcp_server") .. '</span>')
                end
                if (host.services.dns) then
                    print(' <span class="badge bg-success">' .. i18n("details.label_dns_server") .. '</span>')
                end
                if (host.services.smtp) then
                    print(' <span class="badge bg-success">' .. i18n("details.label_smtp_server") .. '</span>')
                end
                if (host.services.ntp) then
                    print(' <span class="badge bg-success">' .. i18n("details.label_ntp_server") .. '</span>')
                end
                if (host.services.imap) then
                    print(' <span class="badge bg-success">' .. i18n("details.label_imap_server") .. '</span>')
                end
                if (host.services.pop) then
                    print(' <span class="badge bg-success">' .. i18n("details.label_pop_server") .. '</span>')
                end
            end

            if (host["dhcp_server"] == true) then
                print(' <span class="badge bg-success" style="cursor: help;">' .. i18n("details.label_dhcp_server") ..
                          '</span>')
            end
            if (host["systemhost"] == true) then
                print(' <span class="badge bg-success" style="cursor: help;"><i class=\"fas fa-flag\" title=\"' ..
                          i18n("details.label_system_ip") .. '\"></i></span>')
            end
            if (host["is_blacklisted"] == true) then
                print(" <a href='"..ntop.getHttpPrefix().."/lua/admin/blacklists.lua?enabled_status=enabled'><span class='badge bg-danger'>" .. i18n("details.label_blacklisted_host"))

                if (host.blacklist_name ~= nil) then
                    print(' (' .. host.blacklist_name .. ')')
                end

                print('</span></a>')
            end

            if ((host["privatehost"] == false) and (host["is_multicast"] == false) and (host["is_broadcast"] == false)) then
                print(
                    ' <A class="ntopng-external-link" href="https://www.virustotal.com/gui/ip-address/' .. host["ip"] ..
                        '/detection" target=_blank><small>VirusTotal</small> <i class=\"fas fa-external-link-alt\"></i></A>')
                print(' <A class="ntopng-external-link" href="https://www.abuseipdb.com/check/' .. host["ip"] ..
                          '" target=_blank><small>AbuseIP DB</small> <i class=\"fas fa-external-link-alt\"></i></A>')
            end
	    
	    if (host["os"] == 0) then
	       -- Print the TCP Fingerprint when the OS is Unknown
	       if(host["tcp_fingerprint"] ~= nil) then
		  print(" <span class=\"badge bg-secondary\">TCP Fingerprint: "..host["tcp_fingerprint"].. "</span>")
	       end
	    end

	    if(false) then
	       if(host.fingerprint ~= nil) then
		  if(host.fingerprint.os ~= "Unknown") then
		     print(' <span class="badge bg-success">OS: '.. host.fingerprint.os .. '</span>')
		  else
		     print(' <span class="badge bg-warning">TCP Fingerprint: '.. host.fingerprint.tcp .. '</span>')
		  end
	       end
	    end
	    
            print("</td>\n")
        end
	
	
        local h_notes = getHostNotes(host_info) or ''

        if (not isEmptyString(h_notes)) then
            print [[

            <tr><th>]]
            print(i18n("host_details.notes"))
            print [[</th><td colspan="2"><span id="host_notes">]]
            print(h_notes)
            print [[</span><span id="host_notes"></span></td></tr>

            ]]
        end

        if (host["num_alerts"] > 0) then
            print("<tr><th><i class=\"fas fa-exclamation-triangle\" style='color: #B94A48;'></i> " ..
                      i18n("show_alerts.engaged_alerts") .. "</th><td colspan=2></li>" .. hostinfo2detailshref(host, {
                page = "engaged-alerts"
            }, "<span id=num_alerts>" .. host["num_alerts"] .. "</span>") ..
                      " <span id=alerts_trend></span></td></tr>\n")
        end

        -- Active monitoring
        if am_utils and am_utils.isMeasurementAvailable('icmp') then
            local icmp = isIPv6(host["ip"]) and 'icmp6' or 'icmp'
            print([[
         <tr>
            <th>]] .. i18n("active_monitoring_stats.active_monitoring") .. [[</th>
         ]])
            if (not am_utils.hasHost(host["ip"], icmp)) then
                print([[
            <td colspan="2">
               <a href='#' id='btn-add-am-host'>]] .. i18n('active_monitoring_stats.add_icmp') ..
                          [[ <i class='fas fa-plus'></i></a>
            </td>
            <script type='text/javascript'>
               $(document).ready(function() {

                  let am_csrf = "]] .. ntop.getRandomCSRFValue() .. [[";
                  $('#btn-add-am-host').click(function(e) {

                     e.preventDefault();
                     const data_to_send = {
                        action: 'add',
                        am_host: ']] .. host["ip"] .. [[',
                        threshold: 100,
                        granularity: "min",
                        measurement: ']] .. icmp .. [[',
                        csrf: am_csrf,
                     };

                     $.post(`${http_prefix}/lua/edit_active_monitoring_host.lua`, data_to_send)
                     .then((data, result, xhr) => {

                        const $alert_message = $('<div class="alert"></div>');
                        if (data.success) {
                           $alert_message.addClass('alert-success').text(data.message);
                           $('#n-container').prepend($alert_message);

                           setTimeout(() => {
                              location.reload();
                           }, 1000);

                           return;
                        }

                        $alert_message.addClass('alert-danger').text(data.error);
                        $('#n-container').prepend($alert_message);
                        setTimeout(() => {
                           $alert_message.remove();
                        }, 5000);

                     })
                     .fail(() => {
                        const $alert_message = $('<div class="alert"></div>');
                        $alert_message.addClass('alert-danger').text("]] .. i18n('expired_csrf') .. [[");

                     });

                  });
               });
            </script>
         ]])

            else
                local last_update = am_utils.getLastAmUpdate(host['ip'], icmp)
                local last_rtt = ""

                if (last_update ~= nil) then
                    last_rtt = last_update.value .. " " .. i18n("active_monitoring_stats.msec")
                else
                    last_rtt = i18n("active_monitoring_stats.no_updates_yet")
                end

                print([[
            <td colspan="2">
               <a href=']] .. ntop.getHttpPrefix() .. [[/lua/monitor/active_monitoring_monitor.lua?am_host=]] ..
                          host['ip'] .. [[&measurement=]] .. icmp .. [['>]] .. last_rtt .. [[</a>
            </td>
            ]])

            end

            print("</tr>")
        end

        if (host["active_alerted_flows"] > 0) then
            print("<tr><th>" .. i18n("host_details.active_alerted_flows") .. "</th><td colspan=2></li>" ..
                      hostinfo2detailshref(host, {
                    page = "flows",
                    flow_status = "alerted"
                }, "<span id=num_flow_alerts>" .. formatValue(host["active_alerted_flows"]) .. "</span>") ..
                      " <span id=flow_alerts_trend></span></td></tr>\n")
        end

        if((host.num_reset_flows ~= nil) and (host.num_reset_flows > 0)) then
            print("<tr><th>" .. i18n("host_details.attempted_reset_flows") .. "</th><td colspan=2></li>" ..
            "<span id=num_reset_flows>" .. formatValue(host.num_reset_flows) .. "</span>" ..
                    " <span id=flow_alerts_trend></span></td></tr>\n")
        end

        if (host.score_behaviour.tot_num_anomalies > 0) then
            -- TODO: Add JSON update
            print("<tr><th>" .. i18n("host_details.behavioural_anomalies") ..
                      "</th><td colspan=2><span id=beh_anomalies>" ..
                      formatValue(host.score_behaviour.tot_num_anomalies) ..
                      "</span><span id=beh_anomalies_trend></span></td></tr>\n")
        end

        if ntop.isPro() and ifstats.inline and (host["has_blocking_quota"] or host["has_blocking_shaper"]) then

            local msg = ""
            local target = ""
            local quotas_page = hostinfo2detailsurl(host, {
                page = "quota"
            })
            local policies_page = "/lua/if_stats.lua?ifid=" .. ifId .. "&page=filtering&pool=" .. host_pool_id

            if host["has_blocking_quota"] then
                if host["has_blocking_shaper"] then
                    msg = i18n("host_details.host_traffic_blocked_quota_and_shaper")
                    target = quotas_page
                else
                    msg = i18n("host_details.host_traffic_blocked_quota")
                    target = quotas_page
                end
            else
                msg = i18n("host_details.host_traffic_blocked_shaper")
                target = policies_page
            end

            print("<tr><th><i class=\"fas fa-ban fa-lg\"></i> <a href=\"" .. ntop.getHttpPrefix() .. target .. "\">" ..
                      i18n("host_details.blocked_traffic") .. "</a></th><td colspan=2>" .. msg)
            print(".")
            print("</td></tr>")
        end

        print("<tr><th>" .. i18n("details.first_last_seen") .. "</th><td nowrap><span id=first_seen>" ..
                  formatEpoch(host["seen.first"]) .. " [" .. secondsToTime(os.time() - host["seen.first"]) .. " " ..
                  i18n("details.ago") .. "]" .. "</span></td>\n")
        print("<td  width='35%'><span id=last_seen>" .. formatEpoch(host["seen.last"]) .. " [" ..
                  secondsToTime(os.time() - host["seen.last"]) .. " " .. i18n("details.ago") .. "]" ..
                  "</span></td></tr>\n")

        if ((host["bytes.sent"] + host["bytes.rcvd"]) > 0) then
            print("<tr><th>" .. i18n("details.sent_vs_received_traffic_breakdown") .. "</th><td colspan=2>")
            graph_utils.breakdownBar(host["bytes.sent"], i18n("sent"), host["bytes.rcvd"], i18n("details.rcvd"), 0, 100)
            print("</td></tr>\n")
        end

        print("<tr><th>" .. i18n("details.traffic_sent_received") .. "</th><td><span id=pkts_sent>" ..
                  formatPackets(host["packets.sent"]) .. "</span> / <span id=bytes_sent>" ..
                  bytesToSize(host["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" ..
                  formatPackets(host["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>" ..
                  bytesToSize(host["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

        print("<tr><th colspan=4></th></tr>\n")

        if (vs_utils.is_available()) then
            local host_vulnerabilities = vs_utils.retrieve_host(host["ip"])

            if host_vulnerabilities ~= nil and host_vulnerabilities.num_vulnerabilities_found and host_vulnerabilities.num_vulnerabilities_found > 0 then
                if(host_vulnerabilities.last_scan.time == nil) then
                    host_vulnerabilities.last_scan.time = format_utils.formatPastEpochShort(host_vulnerabilities.last_scan.epoch)
                end

                print('<tr><th><a href="' .. ntop.getHttpPrefix() ..'/lua/vulnerability_scan.lua?page=show_result&scan_date='..host_vulnerabilities.last_scan.time..'&host='..host_vulnerabilities.host..'&scan_type='..host_vulnerabilities.scan_type..'">'.. i18n("hosts_stats.page_scan_hosts.title_hosts_page") .. '</a></th>')
                print("<td colspan=2>")
                cve_utils.getFirst5(host_vulnerabilities.cve,host_vulnerabilities.scan_type, true)


            elseif (host_vulnerabilities ~= nil and (host_vulnerabilities.num_vulnerabilities_found == nil or host_vulnerabilities.num_vulnerabilities_found == 0)) then
                print("<tr><th>" .. i18n("hosts_stats.page_scan_hosts.title_hosts_page") .. "</th>")
                print("<td colspan=2>")
                print(i18n("hosts_stats.page_scan_hosts.no_cves_detected"))

            elseif (host_vulnerabilities == nil) then
                print("<tr><th>" .. i18n("hosts_stats.page_scan_hosts.title_hosts_page") .. "</th>")
                print("<td colspan=2>")
                print('<a href="' .. ntop.getHttpPrefix() ..'/lua/vulnerability_scan.lua?page=scan_hosts&host='..host["ip"]..'&ifid='..ifId..'">'.. i18n("hosts_stats.page_scan_hosts.add_to_scan_list")..'</a> ')
            end
        end

        -- ###########################################################

        print("<tr><th></th><th>" .. i18n("details.as_client") .. "</th><th>" .. i18n("details.as_server") ..
                  "</th></tr>\n")

        if isScoreEnabled() then
            local score_chart = ""

            if charts_available then
                score_chart = hostinfo2detailshref(host, {
                    page = "historical",
                    tskey = tskey,
                    ts_schema = "host:score"
                }, '<i class="fas fa-chart-area fa-sm"></i>')
            end

            print("<tr><th>" .. i18n("score") .. " " .. score_chart .. "</th>")

            local c = host.score_pct and host.score_pct["score_breakdown_client"]
            local s = host.score_pct and host.score_pct["score_breakdown_server"]

            print("<td>")
            print("<div class='d-flex align-items-center'>")
            print("<span id='score_as_client'>" .. formatValue(host["score.as_client"] or 0) ..
                      "</span> <span class='ms-1' id='client_score_trend'></span>")
            if c then
                scoreBreakdown(c)
            end
            print("</div>")
            print("</td>")

            print("<td>")
            print("<div class='d-flex align-items-center'>")
            print("<span id='score_as_server'>" .. formatValue(host["score.as_server"] or 0) ..
                      "</span><span class='ms-1' id='server_score_trend'></span>")
            if s then
                scoreBreakdown(s)
            end
            print("</div>")
            print("</td>")

            print("</tr>\n")
        end

        local flows_th = i18n("details.flows_non_packet_iface")
        if interface.isPacketInterface() then
            flows_th = i18n("details.flows_packet_iface")
        end

        print("<tr><th>" .. flows_th .. "</th><td><span id=active_flows_as_client>" ..
                  formatValue(host["active_flows.as_client"]) .. "</span> <span id=trend_as_active_client></span> \n")
        print("/ <span id=flows_as_client>" .. formatValue(host["flows.as_client"]) ..
                  "</span> <span id=trend_as_client></span> \n")
        print("/ <span id=alerted_flows_as_client>" .. formatValue(host["alerted_flows.as_client"]) ..
                  "</span> <span id=trend_alerted_flows_as_client></span>")
        print(" / <span id=unreachable_flows_as_client>" .. formatValue(host["unreachable_flows.as_client"]) ..
                  "</span> <span id=trend_unreachable_flows_as_client></span>")
        print("</td>")

        print("<td><span id=active_flows_as_server>" .. formatValue(host["active_flows.as_server"]) ..
                  "</span>  <span id=trend_as_active_server></span> \n")
        print("/ <span id=flows_as_server>" .. formatValue(host["flows.as_server"]) ..
                  "</span> <span id=trend_as_server></span> \n")
        print("/ <span id=alerted_flows_as_server>" .. formatValue(host["alerted_flows.as_server"]) ..
                  "</span> <span id=trend_alerted_flows_as_server></span>")
        print(" / <span id=unreachable_flows_as_server>" .. formatValue(host["unreachable_flows.as_server"]) ..
                  "</span> <span id=trend_unreachable_flows_as_server></span>")
        print("</td></tr>")

        print("<tr><th>" .. i18n("details.contacts_blacklisted") .. "</th>")
        print("<td><span id=num_blacklisted_flows_as_client>" .. formatValue(host.num_blacklisted_flows.as_client) ..
                  "</span> <span id=trend_num_blacklisted_flows_as_client></span> \n")
        print("<td><span id=num_blacklisted_flows_as_server>" .. formatValue(host.num_blacklisted_flows.as_server) ..
                  "</span>  <span id=trend_num_blacklisted_flows_as_server></span> \n")
        print("</tr>")

        if (host.num_unidirectional_tcp_flows ~= nil) then
            print("<tr><th>" .. i18n("details.unidirectional_tcp_flows") .. "</th>")
            print("<td><span id=num_unidirectional_egress_flows>" ..
                      formatValue(host.num_unidirectional_tcp_flows.num_egress) ..
                      "</span> <span id=trend_num_unidirectional_egress_flows></span>  <a href='" ..
                      ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. host_ip ..
                      "&page=historical&ts_schema=host:host_tcp_unidirectional_flows' data-bs-toggle='tooltip' title=''><i class='fas fa-chart-area'></i></a> \n")
            print("<td><span id=num_unidirectional_ingress_flows>" ..
                      formatValue(host.num_unidirectional_tcp_flows.num_ingress) ..
                      "</span> <span id=trend_num_unidirectional_ingress_flows></span>  <a href='" ..
                      ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. host_ip ..
                      "&page=historical&ts_schema=host:host_tcp_unidirectional_flows' data-bs-toggle='tooltip' title=''><i class='fas fa-chart-area'></i></a> \n")
            print("</tr>")
        end

        print("<tr><th>" .. i18n("details.peers") .. "</th>")
        print("<td><span id=active_peers_as_client>" .. formatValue(host["contacts.as_client"]) ..
                  "</span> <span id=peers_trend_as_active_client></span> \n")
        print("<td><span id=active_peers_as_server>" .. formatValue(host["contacts.as_server"]) ..
                  "</span>  <span id=peers_trend_as_active_server></span> \n")

        if ntop.isnEdge() then
            print("<tr id=bridge_dropped_flows_tr ")
            if not host["flows.dropped"] then
                print("style='display:none;'")
            end
            print(">")

            print("<th><i class=\"fas fa-ban fa-lg\"></i> " .. i18n("details.flows_dropped_by_bridge") .. "</th>")
            print("<td colspan=2><span id=bridge_dropped_flows>" .. formatValue((host["flows.dropped"] or 0)) ..
                      "</span>  <span id=trend_bridge_dropped_flows></span>")

            print("</tr>")
        end

        print("<tr><th>")
        print(i18n("details.server_contacts_tcp_unresponsive"))
        print("</th><td>")
        print("<span id=num_contacted_peers_with_tcp_udp_flows_no_response>" ..
                  formatContacts(host.num_contacted_peers_with_tcp_udp_flows_no_response) ..
                  "</span> <span id=num_contacted_peers_with_tcp_udp_flows_no_response_trend></span> \n")
        print("</td><td>")
        print("<span id=num_incoming_peers_that_sent_tcp_udp_flows_no_response>" ..
                  formatContacts(host.num_incoming_peers_that_sent_tcp_udp_flows_no_response) ..
                  "</span> <span id=num_incoming_peers_that_sent_tcp_udp_flows_no_response_trend></span> \n")
        print("</td>")
        print("</tr>\n")

        print("<tr><th colspan=4></th></tr>\n")

        -- ###########################################################

        if (host.server_contacts ~= nil) then
            print("<tr><th>")

            if (has_assets) then
                print("<a href=\"" .. ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. host_ip ..
                          "&page=assets\">" .. i18n("details.server_contacts") .. "</A>")
            else
                print(i18n("details.server_contacts"))
            end

            print("</th><td colspan=2>")
            print("<b>DNS</b>: " .. formatContacts(host.server_contacts.dns) .. " / ")
            print("<b>SMTP</b>: " .. formatContacts(host.server_contacts.smtp) .. " / ");
            print("<b>POP</b>: " .. formatContacts(host.server_contacts.pop) .. " / ");
            print("<b>IMAP</b>: " .. formatContacts(host.server_contacts.imap) .. " / ");
            print("<b>NTP</b>: " .. formatContacts(host.server_contacts.ntp));
            print("</tr></tr>\n")
        end

        if host["tcp.packets.seq_problems"] == true then
            local tcp_seq_label = "TCP: " .. i18n("details.retransmissions") .. " / " .. i18n("details.out_of_order") ..
                                      " / " .. i18n("details.lost") .. " / " .. i18n("details.keep_alive")

            -- SENT ANALYSIS
            local tcp_retx_sent = "<span id=pkt_retransmissions_sent>" ..
                                      formatPackets(host["tcpPacketStats.sent"]["retransmissions"]) ..
                                      "</span> <span id=pkt_retransmissions_sent_trend></span>"
            local tcp_ooo_sent =
                "<span id=pkt_ooo_sent>" .. formatPackets(host["tcpPacketStats.sent"]["out_of_order"]) ..
                    "</span> <span id=pkt_ooo_sent_trend></span>"
            local tcp_lost_sent = "<span id=pkt_lost_sent>" .. formatPackets(host["tcpPacketStats.sent"]["lost"]) ..
                                      "</span> <span id=pkt_lost_sent_trend></span>"
            local tcp_keep_alive_sent = "<span id=pkt_keep_alive_sent>" ..
                                            formatPackets(host["tcpPacketStats.sent"]["keep_alive"]) ..
                                            "</span> <span id=pkt_keep_alive_sent_trend></span>"

            -- RCVD ANALYSIS
            local tcp_retx_rcvd = "<span id=pkt_retransmissions_rcvd>" ..
                                      formatPackets(host["tcpPacketStats.rcvd"]["retransmissions"]) ..
                                      "</span> <span id=pkt_retransmissions_rcvd_trend></span>"
            local tcp_ooo_rcvd =
                "<span id=pkt_ooo_rcvd>" .. formatPackets(host["tcpPacketStats.rcvd"]["out_of_order"]) ..
                    "</span> <span id=pkt_ooo_rcvd_trend></span>"
            local tcp_lost_rcvd = "<span id=pkt_lost_rcvd>" .. formatPackets(host["tcpPacketStats.rcvd"]["lost"]) ..
                                      "</span> <span id=pkt_lost_rcvd_trend></span>"
            local tcp_keep_alive_rcvd = "<span id=pkt_keep_alive_rcvd>" ..
                                            formatPackets(host["tcpPacketStats.rcvd"]["keep_alive"]) ..
                                            "</span> <span id=pkt_keep_alive_rcvd_trend></span>"

            print("<tr><th rowspan=2>" .. tcp_seq_label .. "</th><th>" .. i18n("sent") .. "</th><th>" ..
                      i18n("received") .. "</th></tr>")
            print("<tr><td>" ..
                      string.format("%s / %s / %s / %s", tcp_retx_sent, tcp_ooo_sent, tcp_lost_sent, tcp_keep_alive_sent) ..
                      "</td><td>" ..
                      string.format("%s / %s / %s / %s", tcp_retx_rcvd, tcp_ooo_rcvd, tcp_lost_rcvd, tcp_keep_alive_rcvd) ..
                      "</td></tr>")
        end

        -- Stats reset
        print(template.gen("modal_confirm_dialog.html", {
            dialog = {
                id = "reset_host_stats_dialog",
                action = "$('#reset_host_stats_form').submit();",
                title = i18n("host_details.reset_host_stats"),
                message = i18n("host_details.reset_host_stats_confirm", {
                    host = host_label
                }) .. "<br><br>" .. i18n("host_details.reset_host_stats_note"),
                confirm = i18n("reset")
            }
        }))

        -- Stats reset
        print(template.gen("modal_confirm_dialog.html", {
            dialog = {
                id = "reset_blacklisted_stats_dialog",
                action = "$('#reset_blacklisted_stats_form').submit();",
                title = i18n("host_details.reset_blacklisted_stats"),
                message = i18n("host_details.reset_blacklisted_stats_confirm", {
                    host = host_label
                }) .. "<br><br>" .. i18n("host_details.reset_blacklisted_stats_note"),
                confirm = i18n("reset")
            }
        }))
        print [[<tr><th width=30% >]]
        print(i18n("host_details.reset_host_stats"))
        print [[</th><td colspan=2><form id='reset_host_stats_form' method="POST">
      <input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
      <input name="action" type="hidden" value="reset_stats" />
      <input name="resetstats_mode" type="hidden" value="reset_all" />
   </form>
   <form id='reset_blacklisted_stats_form' method="POST">
      <input name="csrf" type="hidden" value="]]
        print(ntop.getRandomCSRFValue())
        print [[" />
      <input name="action" type="hidden" value="reset_stats" />
      <input name="resetstats_mode" type="hidden" value="reset_blacklisted" />
   </form>
   <button class="btn btn-secondary" onclick="$('#reset_host_stats_dialog').modal('show')">]]
        print(i18n("host_details.reset_host_stats"))
        print [[</button>
   <button class="btn btn-secondary" onclick="$('#reset_blacklisted_stats_dialog').modal('show')">]]
        print(i18n("host_details.reset_blacklisted_stats"))
        print [[</button>

   </td></tr>]]

        local num_extra_names = 0
        local extra_names = host["names"]
        local num_extra_names = table.len(extra_names)

        if num_extra_names > 0 then
            local name_sources = {}
            for source, name in pairsByKeys(extra_names, rev) do
                if source == "resolved" then
                    source = "DNS Resolution"
                else
		   if(string.find(source, " ") == nil) then
			 source = source:upper()
		   end
                end

                if not name_sources[name] then
                    name_sources[name] = source
                else
                    -- Collapse multiple sources in a single row when the name is the same
                    name_sources[name] = string.format("%s, %s", source, name_sources[name])
                    num_extra_names = num_extra_names - 1
                end
            end

            print('<tr><td width=35% rowspan=' .. (num_extra_names + 1) .. '><b>' ..
                      i18n("details.further_host_names_information") .. ' </a></b></td>')
            print("<th>" .. i18n("details.source") .. "</th><th>" .. i18n("name") .. "</th></tr>\n")
            for name, source in pairsByValues(name_sources, asc) do
                print("<tr><td>" .. source .. "</td><td>" .. name .. "</td></tr>\n")
            end
        end

	if(table.len(host.os_learning) > 0) then
	   print('<tr><td width=35% rowspan=' .. (table.len(host.os_learning) + 1) .. '><b>' ..
		 i18n("details.os_learning") .. ' </a></b></td>')
	   print("<th>" .. i18n("details.source") .. "</th><th>" .. i18n("advertised_os") .. "</th></tr>\n")
	   for source, osname in pairsByValues(host.os_learning, asc) do
	      print("<tr><td>" .. source .. "</td><td>" .. osname .. "</td></tr>\n")
            end
	end
	
        if host["device_ip"] then
            print('<tr><td width=35% rowspan=' .. (table.len(host["devices_ip"]) + 1) .. '><b>' ..
                      i18n("details.probes_ipv4_address") .. ' </a></b></td>')
            print("<td colspan='2'>" .. host["device_ip"])
            if host["more_then_one_device"] then
                print(i18n("details.more_then_one_device"))
            end
            print("</td></tr>\n")
        end

        print("<tr><th>" .. i18n("download") .. "&nbsp;<i class=\"fas fa-download fa-lg\"></i></th><td")
        local show_live_capture = ntop.isPcapDownloadAllowed()
        if (not show_live_capture) then
            print(" colspan=2")
        end
        print("><A HREF='" .. ntop.getHttpPrefix() .. "/lua/rest/v2/get/host/data.lua?ifid=" .. ifId .. "&" ..
                  hostinfo2url(host_info) .. "' download='host-" .. host_ip .. ".json'>JSON</A></td>")
        print [[<td>]]
        if (show_live_capture and ifstats.isView == false and not interface.isSubInterface() and
            interface.isPacketInterface()) then
            local live_traffic_utils = require("live_traffic_utils")
            live_traffic_utils.printLiveTrafficForm(ifId, host_info)
        end

        print [[</td>]]
        print("</tr>\n")

        if (host["ssdp"] ~= nil) then
            print(
                "<tr><th><A class='ntopng-external-link' href='https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol'>SSDP (UPnP)<i class=\"fas fa-external-link-alt fa-lg\"></i></A></th><td colspan=2> <A HREF='" ..
                    host["ssdp"] .. "'>" .. host["ssdp"] .. "<A></td></tr>\n")
        end



        print("<tr><th colspan=4></th></tr>\n")

        print("</table>\n")
        print [[
        </div>
        </div>
      </div>
    </div>]]

    elseif ((page == "packets")) then
        template.render("pages/hosts/packets_stats.template", {
            view = "applications",
            host_ip = host_ip,
            vlan = host_vlan,
            ifid = ifId
        })
    elseif ((page == "peers")) then
        host_info = url2hostinfo(_GET)
        peers = getTopFlowPeers(hostinfo2hostkey(host_info), 1 --[[exists query]] )
        found = 0

        for key, value in pairs(peers) do
            found = 1
            break
        end

        if (found) then
            print [[

   <br />
   <table border=0>
   <tr>
     <td>
       <div id="chart-row-hosts">
         <strong>]]
            print(i18n("peers_page.top_peers_for_host", {
                hostkey = hostinfo2hostkey(host_info)
            }))
            print [[</strong>
         <div class="clearfix"></div>
       </div>

       <div id="chart-ring-protocol">
         <strong>]]
            print(i18n("peers_page.top_peer_protocol"))
            print [[</strong>
         <div class="clearfix"></div>
       </div>
     </td>
   </tr>
   </table>
   <br />
   <table class="table table-hover dc-data-table">
        <thead>
        <tr class="header">
            <th>]]
            print(i18n("peers_page.host"))
            print [[</th>
            <th>]]
            print(i18n("application"))
            print [[</th>
            <th>]]
            print(i18n("peers_page.traffic_volume"))
            print [[</th>
        </tr>
        </thead>
   </table>

<script>
var protocolChart = dc.pieChart("#chart-ring-protocol");
var hostChart     = dc.rowChart("#chart-row-hosts");

$.ajax({
      type: 'GET',]]
            print("url: '" .. ntop.getHttpPrefix() .. "/lua/host_top_peers_protocols.lua?ifid=" .. ifId .. "&host=" ..
                      host_info["host"])
            if ((host_info["vlan"] ~= nil) and ifstats.vlan) then
                print("&vlan=" .. host_info["vlan"])
            end
            print("',\n")
            print [[
      data: { },
      error: function(content) { console.log("Host Top Peers: Parse error"); },
      success: function(content) {
   var rsp;
// set crossfilter
var ndx = crossfilter(content),
    protocolDim  = ndx.dimension(function(d) {return d.l7proto;}),
    trafficDim = ndx.dimension(function(d) {return Math.floor(d.traffic/10);}),
    nameDim  = ndx.dimension(function(d) {return d.name;});
    // actually this script expects input data to be aggregated by host, otherwise we are making the sum of logarithms here
    trafficPerl7proto = protocolDim.group().reduceSum(function(d) {return +d.traffic;}),
    trafficPerhost = nameDim.group().reduceSum(function(d) {return +d.traffic;}),
    trafficHist    = trafficDim.group().reduceCount();

protocolChart
    .width(400).height(300)
    .dimension(protocolDim)
    .group(trafficPerl7proto)
    .innerRadius(70);

// Tooltip
protocolChart.title(function(d){
      return d.key+": " + NtopUtils.bytesToVolume(d.value);
      })

hostChart
    .width(800).height(300)
    .dimension(nameDim)
    .group(trafficPerhost)
    .elasticX(true);

// Tooltip
hostChart.title(function(d){
      return "Host "+d.key+": " + NtopUtils.bytesToVolume(d.value);
      })

hostChart.xAxis().tickFormat(function(v) {
  if(v < 1024)
    return(v.toFixed(2));
  else
    return NtopUtils.bytesToVolume(v);
});

  // dimension by full date
    var dateDimension = ndx.dimension(function (d) {
        return d.host;
    });

   dc.dataTable(".dc-data-table")
        .dimension(dateDimension)
        .group(function (d) { return d.name; })
        .size(10) // (optional) max number of records to be shown, :default = 25
        // dynamic columns creation using an array of closures
        .columns([
            function (d) {
                return d.url;
            },
            function (d) {
                return d.l7proto_url;
            },
            function (d) {
                return NtopUtils.bytesToVolume(d.traffic);
            }
        ])
        // (optional) sort using the given field, :default = function(d){return d;}
        .sortBy(function (d) {
            return +d.traffic;
        })
        // (optional) sort order, :default ascending
        .order(d3.descending)
        // (optional) custom renderlet to post-process chart using D3
        .renderlet(function (table) {
            table.selectAll(".dc-table-group").classed("info", true);
        });


dc.renderAll();
}
});

</script>
   ]]
        else
            print(
                "<disv class=\"alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> " ..
                    i18n("peers_page.no_active_flows_message") .. "</div>")
        end
    elseif ((page == "traffic")) then
        -- template render
        template.render("pages/hosts/traffic_stats.template", {})

    elseif ((page == "ports")) then
        print('<table class="table table-bordered table-striped">\n')

        if (host.used_ports ~= nil) then
            local len
            if (table.len(host.used_ports.local_server_ports) == 0) then
                len = ""
            else
                len = "rowspan=2"
            end

            print('\n<tr><th class="text-start" ' .. len .. '>' .. i18n("ports_page.active_server_ports") .. '</th>')
            printPorts(host.used_ports.local_server_ports, true)

            if (table.len(host.used_ports.remote_contacted_ports) == 0) then
                len = ""
            else
                len = "rowspan=2"
            end
            print('\n<tr><th class="text-start" ' .. len .. '>' .. i18n("ports_page.client_contacted_server_ports") ..
                      '</th>')
            printPorts(host.used_ports.remote_contacted_ports, false)
        end

        print('<tr><th class="text-start">' .. i18n("ports_page.client_ports") ..
                  '</th><td colspan=5><div class="pie-chart" id="clientPortsDistro"></div></td></tr>')
        print('<tr><th class="text-start">' .. i18n("ports_page.server_ports") ..
                  '</th><td colspan=5><div class="pie-chart" id="serverPortsDistro"></div></td></tr>')

        print [[
  </table>
    <script type='text/javascript'>
           window.onload=function() {
               do_pie("#clientPortsDistro", ']]
        print(ntop.getHttpPrefix())
        print [[/lua/iface_ports_list.lua', { clisrv: "client", ifid: "]]
        print(ifId .. "")
        print('", ' .. hostinfo2json(host_info) .. "}, \"\", refresh); \n")
        print [[
               do_pie("#serverPortsDistro", ']]
        print(ntop.getHttpPrefix())
        print [[/lua/iface_ports_list.lua', { clisrv: "server", ifid: "]]
        print(ifId .. "")
        print('", ' .. hostinfo2json(host_info) .. "}, \"\", refresh); \n")
        print [[
            }
        </script><p>
    ]]
        -- template render
        -- template.render("pages/hosts/ports_stats.template", {})

    elseif ((page == "listening_ports")) then
        template.render("htmlPages/hostDetails/listening-ports.template", {
            processes_endpoint = "/lua/rest/v2/get/host/processes/listening_ports.lua",
            host = host_ip,
            vlan = host_vlan,
            http_prefix = ntop.getHttpPrefix(),
            csrf = ntop.getRandomCSRFValue()
        })

    elseif ((page == "ICMP")) then

        print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]]
        print(i18n("icmp_page.icmp_message"))
        print [[</th><th>]]
        print(i18n("icmp_page.icmp_type"))
        print [[</th><th>]]
        print(i18n("icmp_page.icmp_code"))
        print [[</th><th>]]
        print(i18n("icmp_page.last_sent_peer"))
        print [[</th><th>]]
        print(i18n("icmp_page.last_rcvd_peer"))
        print [[</th><th>]]
        print(i18n("breakdown"))
        print [[</th><th style='text-align:right;'>]]
        print(i18n("icmp_page.packets_sent"))
        print [[</th><th style='text-align:right;'>]]
        print(i18n("icmp_page.packets_received"))
        print [[</th><th style='text-align:right;'>]]
        print(i18n("total"))
        print [[</th></tr></thead>
     <tbody id="host_details_icmp_tbody">
     </tbody>
     </table>

<script>
function update_icmp_table() {
  $.ajax({
    type: 'GET',
    url: ']]
        print(ntop.getHttpPrefix())
        print [[/lua/get_icmp_data.lua',
    data: { ifid: "]]
        print(ifId .. "")
        print("\" , ")
        print(hostinfo2json(host_info))

        print [[ },
    success: function(content) {
      $('#host_details_icmp_tbody').html(content);
      $('#myTable').trigger("update");
    }
  });
}

update_icmp_table();
setInterval(update_icmp_table, 5000);

</script>

]]
    elseif ((page == "ndpi")) then
        local tot_cat_series = ts_utils.listSeries("host:ndpi_categories", {host= host_ip, ifid= ifId}, os.time())
        local tot_l7_series = ts_utils.listSeries("host:ndpi", {host= host_ip, ifid= ifId}, os.time())

        local is_l7_series_present = tot_l7_series ~= nil and (not table.empty(tot_l7_series))
        local is_cat_series_present = tot_cat_series ~= nil and (not table.empty(tot_cat_series))

        local timeseries_l7_enabled = areHostTimeseriesEnabled(ifId) and areHostL7TimeseriesEnabled(ifId) and is_l7_series_present
        local timeseries_cat_enabled = areHostTimeseriesEnabled(ifId) and areHostCategoriesTimeseriesEnabled(ifId) and is_cat_series_present

        template.render("pages/hosts/l7_stats.template", {
            view = "applications",
            host_ip = host_ip,
            vlan = host_vlan,
            ifid = ifId,
            is_locale = ternary(host["localhost"],"1","0"),
            ts_l7_enabled = timeseries_l7_enabled,
            ts_cat_enabled = timeseries_cat_enabled
        })
    elseif (page == "assets") then
        if (ntop.isEnterpriseL()) then
            local asset_map_utils = require "asset_map_utils"

            asset_map_utils.printHostAssets(host.asset_key)
        end
    elseif (page == "dns") then
        if ((host.DoH_DoT ~= nil) or (host["dns"] ~= nil)) then
            print("<table class=\"table table-bordered table-striped\">\n")

            if (host.DoH_DoT ~= nil) then
                print("<tr><th>" .. i18n("dns_page.doh_dot_servers") .. "</th><th colspan=4>" ..
                          i18n("dns_page.doh_dot_server_uses") .. "</th></tr>")

                for _, v in pairs(host.DoH_DoT) do
                    print(
                        "<tr><th>" .. buildHostHREF(v.ip, v.vlan_id, "overview") .. "</th><td colspan=4 align=right>" ..
                            formatValue(v.num_uses) .. "</td>")
                end

                print("</td></tr>\n")
            end

            if (host["dns"] ~= nil) then
                print("<tr><th>" .. i18n("dns_page.dns_breakdown") .. "</th><th class='text-end'>" ..
                          i18n("dns_page.queries") .. "</th><th class='text-end'>" .. i18n("dns_page.positive_replies") ..
                          "</th><th class='text-end'>" .. i18n("dns_page.error_replies") ..
                          "</th><th colspan=2 class='text-center'>" .. i18n("dns_page.reply_breakdown") .. "</th></tr>")
                print("<tr><th>" .. i18n("sent") .. "</th><td class=\"text-end\"><span id=dns_sent_num_queries>" ..
                          formatValue(host["dns"]["sent"]["num_queries"]) ..
                          "</span> <span id=trend_sent_num_queries></span></td>")

                print("<td class=\"text-end\"><span id=dns_sent_num_replies_ok>" ..
                          formatValue(host["dns"]["sent"]["num_replies_ok"]) ..
                          "</span> <span id=trend_sent_num_replies_ok></span></td>")
                print("<td class=\"text-end\"><span id=dns_sent_num_replies_error>" ..
                          formatValue(host["dns"]["sent"]["num_replies_error"]) ..
                          "</span> <span id=trend_sent_num_replies_error></span></td><td colspan=2>")
                graph_utils.breakdownBar(host["dns"]["sent"]["num_replies_ok"], "OK",
                    host["dns"]["sent"]["num_replies_error"], "Error", 0, 100)
                print("</td></tr>")

                print("<tr><th>" .. i18n("dns_page.rcvd") ..
                          "</th><td class=\"text-end\"><span id=dns_rcvd_num_queries>" ..
                          formatValue(host["dns"]["rcvd"]["num_queries"]) ..
                          "</span> <span id=trend_rcvd_num_queries></span></td>")
                print("<td class=\"text-end\"><span id=dns_rcvd_num_replies_ok>" ..
                          formatValue(host["dns"]["rcvd"]["num_replies_ok"]) ..
                          "</span> <span id=trend_rcvd_num_replies_ok></span></td>")
                print("<td class=\"text-end\"><span id=dns_rcvd_num_replies_error>" ..
                          formatValue(host["dns"]["rcvd"]["num_replies_error"]) ..
                          "</span> <span id=trend_rcvd_num_replies_error></span></td><td colspan=2>")
                graph_utils.breakdownBar(host["dns"]["rcvd"]["num_replies_ok"], "OK",
                    host["dns"]["rcvd"]["num_replies_error"], "Error", 50, 100)
                print("</td></tr>")

                if host["dns"]["rcvd"]["num_replies_ok"] + host["dns"]["rcvd"]["num_replies_error"] > 0 then
                    print('<tr><th>' .. i18n("dns_page.request_vs_reply") .. '</th>')
                    local dns_ratio = tonumber(host["dns"]["sent"]["num_queries"]) /
                                          tonumber(
                            host["dns"]["rcvd"]["num_replies_ok"] + host["dns"]["rcvd"]["num_replies_error"])
                    local dns_ratio_str = string.format("%.2f", dns_ratio)

                    if (dns_ratio < 0.9) then
                        dns_ratio_str = "<font color=red>" .. dns_ratio_str .. "</font>"
                    end

                    print('<td colspan=2 align=right>' .. dns_ratio_str .. '</td><td colspan=2>')
                    graph_utils.breakdownBar(host["dns"]["sent"]["num_queries"], i18n("dns_page.queries"),
                        host["dns"]["rcvd"]["num_replies_ok"] + host["dns"]["rcvd"]["num_replies_error"],
                        i18n("dns_page.replies"), 30, 70)

                    print [[</td></tr>]]
                end

                -- Charts
                if ((host["dns"]["sent"]["num_queries"] + host["dns"]["rcvd"]["num_queries"]) > 0) then
                    print [[<tr><th>]]
                    print(i18n("dns_page.dns_query_sent_vs_rcvd_distribution"))
                    print [[</th>]]
                    if (host["dns"]["sent"]["num_queries"] > 0) then
                        print [[<td colspan=2>
                     <div class="pie-chart" id="dnsSent"></div>
                     <script type='text/javascript'>

                                         do_pie("#dnsSent", ']]
                        print(ntop.getHttpPrefix())
                        print [[/lua/host_dns_breakdown.lua', { ]]
                        print(hostinfo2json(host_info))
                        print [[, direction: "sent" }, "", refresh);
                                      </script>
                                         </td>
           ]]
                    else
                        print [[<td colspan=2>&nbsp;</td>]]
                    end

                    if (host["dns"]["rcvd"]["num_queries"] > 0) then
                        print [[
         <td colspan=2><div class="pie-chart" id="dnsRcvd"></div>
         <script type='text/javascript'>

             do_pie("#dnsRcvd", ']]
                        print(ntop.getHttpPrefix())
                        print [[/lua/host_dns_breakdown.lua', { ]]
                        print(hostinfo2json(host_info))
                        print [[, direction: "recv" }, "", refresh);
         </script>
         </td>
]]
                    else
                        print [[<td colspan=2>&nbsp;</td>]]
                    end
                    print("</tr>")
                end

                print [[
        </table>
       <small><b>]]
                print(i18n("dns_page.note"))
                print [[:</b><br>]]
                print(i18n("dns_page.note_dns_ratio"))
                print [[
</small>
]]
            end
        end

    elseif (page == "tls") then
        local fingerprint_type = 'ja4'
        local context = {
            fingerprint_type = fingerprint_type,
            ifid = ifId,
            host = host_ip
        }

        print(template.gen("pages/host_tls.template", context))

    elseif (page == "ssh") then
        local fingerprint_type = 'hassh'
        local context = {
            fingerprint_type = fingerprint_type,
            ifid = ifId,
            host = host_ip
        }

        print(template.gen("pages/host_ssh.template", context))
    elseif (page == "http") then
        local http = host["http"]
        if http then
            print("<table class=\"table table-bordered table-striped\">\n")

            if http["sender"]["query"]["total"] > 0 then
                print(
                    "<tr><th rowspan=6 width=20%><A HREF='http://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods'>" ..
                        i18n("http_page.http_queries") .. "</A></th><th width=20%>" .. i18n("http_page.method") ..
                        "</th><th width=20% class='text-end'>" .. i18n("http_page.requests") ..
                        "</th><th colspan=2 class='text-center'>" .. i18n("http_page.distribution") .. "</th></tr>")
                print("<tr><th>GET</th><td style=\"text-align: right;\"><span id=http_query_num_get>" ..
                          formatValue(http["sender"]["query"]["num_get"]) ..
                          "</span> <span id=trend_http_query_num_get></span></td><td colspan=2 rowspan=5>")

                print [[
         <div class="pie-chart" id="httpQueries"></div>
         <script type='text/javascript'>

             do_pie("#httpQueries", ']]
                print(ntop.getHttpPrefix())
                print [[/lua/host_http_breakdown.lua', { ]]
                print(hostinfo2json(host_info))
                print [[, http_mode: "queries" }, "", refresh);
         </script>
]]

                print("</td></tr>")
                print("<tr><th>POST</th><td style=\"text-align: right;\"><span id=http_query_num_post>" ..
                          formatValue(http["sender"]["query"]["num_post"]) ..
                          "</span> <span id=trend_http_query_num_post></span></td></tr>")
                print("<tr><th>HEAD</th><td style=\"text-align: right;\"><span id=http_query_num_head>" ..
                          formatValue(http["sender"]["query"]["num_head"]) ..
                          "</span> <span id=trend_http_query_num_head></span></td></tr>")
                print("<tr><th>PUT</th><td style=\"text-align: right;\"><span id=http_query_num_put>" ..
                          formatValue(http["sender"]["query"]["num_put"]) ..
                          "</span> <span id=trend_http_query_num_put></span></td></tr>")
                print("<tr><th>" .. i18n("http_page.other_method") ..
                          "</th><td style=\"text-align: right;\"><span id=http_query_num_other>" ..
                          formatValue(http["sender"]["query"]["num_other"]) ..
                          "</span> <span id=trend_http_query_num_other></span></td></tr>")
            end

            if http["receiver"]["response"]["total"] > 0 then
                print("<tr><th rowspan=6 width=20%><A HREF='http://en.wikipedia.org/wiki/List_of_HTTP_status_codes'>" ..
                          i18n("http_page.http_responses") .. "</A></th><th width=20%>" ..
                          i18n("http_page.response_code") .. "</th><th width=20% class='text-end'>" ..
                          i18n("http_page.responses") .. "</th><th colspan=2 class='text-center'>" ..
                          i18n("http_page.distribution") .. "</th></tr>")
                print("<tr><th>" .. i18n("http_page.response_code_1xx") ..
                          "</th><td style=\"text-align: right;\"><span id=http_response_num_1xx>" ..
                          formatValue(http["receiver"]["response"]["num_1xx"]) ..
                          "</span> <span id=trend_http_response_num_1xx></span></td><td colspan=2 rowspan=5>")
                print [[
         <div class="pie-chart" id="httpResponses"></div>
         <script type='text/javascript'>

             do_pie("#httpResponses", ']]
                print(ntop.getHttpPrefix())
                print [[/lua/host_http_breakdown.lua', { ]]
                print(hostinfo2json(host_info))
                print [[, http_mode: "responses" }, "", refresh);
         </script>
]]
                print("</td></tr>")
                print("<tr><th>" .. i18n("http_page.response_code_2xx") ..
                          "</th><td style=\"text-align: right;\"><span id=http_response_num_2xx>" ..
                          formatValue(http["receiver"]["response"]["num_2xx"]) ..
                          "</span> <span id=trend_http_response_num_2xx></span></td></tr>")
                print("<tr><th>" .. i18n("http_page.response_code_3xx") ..
                          "</th><td style=\"text-align: right;\"><span id=http_response_num_3xx>" ..
                          formatValue(http["receiver"]["response"]["num_3xx"]) ..
                          "</span> <span id=trend_http_response_num_3xx></span></td></tr>")
                print("<tr><th>" .. i18n("http_page.response_code_4xx") ..
                          "</th><td style=\"text-align: right;\"><span id=http_response_num_4xx>" ..
                          formatValue(http["receiver"]["response"]["num_4xx"]) ..
                          "</span> <span id=trend_http_response_num_4xx></span></td></tr>")
                print("<tr><th>" .. i18n("http_page.response_code_5xx") ..
                          "</th><td style=\"text-align: right;\"><span id=http_response_num_5xx>" ..
                          formatValue(http["receiver"]["response"]["num_5xx"]) ..
                          "</span> <span id=trend_http_response_num_5xx></span></td></tr>")
            end

            local vh = http["virtual_hosts"]
            if vh then
                local now = os.time()
                local ago1h = now - 3600
                local num = table.len(vh)
                if (num > 0) then
                    local ifId = getInterfaceId(ifname)
                    print("<tr><th rowspan=" .. (num + 1) .. " width=20%>" .. i18n("http_page.virtual_hosts") ..
                              "</th><th>Name</th><th>" .. i18n("http_page.traffic_sent") .. "</th><th>" ..
                              i18n("http_page.traffic_received") .. "</th><th>" .. i18n("http_page.requests_served") ..
                              "</th></tr>\n")
                    for k, v in pairsByKeys(vh, asc) do
                        local j = string.gsub(k, "%.", "___")
                        print("<tr><td>" .. format_external_link(k, k, false, "https") .. "")
                        historicalProtoHostHref(ifId, host, nil, nil, k, host_vlan)
                        print("</td>")
                        print("<td align=right><span id=" .. j .. "_bytes_vhost_sent>" ..
                                  bytesToSize(vh[k]["bytes.sent"]) .. "</span></td>")
                        print("<td align=right><span id=" .. j .. "_bytes_vhost_rcvd>" ..
                                  bytesToSize(vh[k]["bytes.rcvd"]) .. "</span></td>")
                        print("<td align=right><span id=" .. j .. "_num_vhost_req_serv>" ..
                                  formatValue(vh[k]["http.requests"]) .. "</span></td></tr>\n")
                    end
                end
            end

            print("</table>\n")
        end

    elseif (page == "sites") then
        if not prefs.are_top_talkers_enabled then
            local msg = i18n("sites_page.top_sites_not_enabled_message", {
                url = ntop.getHttpPrefix() .. "/lua/admin/prefs.lua?tab=protocols"
            })
            print("<div class='alert alert-info'><i class='fas fa-info-circle fa-lg' aria-hidden='true'></i> " .. msg ..
                      "</div>")

        elseif table.len(sites_granularities) > 0 then
            local endpoint = string.format(ntop.getHttpPrefix() ..
                                               "/lua/pro/rest/v2/get/host/top/local/sites.lua?ifid=%s&host=%s&vlan=%s",
                ifId, host_ip, host_vlan)
            local context = {
                json = json,
                template = template,
                sites = {
                    endpoint = endpoint,
                    host = host_ip,
                    ifid = ifId,
                    vlan = host_vlan,
                    granularities = sites_granularities,
                    default_granularity = "current"
                }
            }

            -- interface.resetHostTopSites(host_info["host"], host_vlan)

            print(template.gen("pages/top_sites.template", context))
        else
            local msg = i18n("sites_page.top_sites_not_seen")
            print("<div class='alert alert-info'><i class='fas fa-info-circle fa-lg' aria-hidden='true'></i> " .. msg ..
                      "</div>")
        end

    elseif (page == "flows") then

        require("flow_utils")
        local flows_page_type = _GET["flows_page_type"] or "live_flows"

        printTabList("host_details.lua?page=flows", {
            host = hostinfo2hostkey(host)
        }, flows_page_type)

        if flows_page_type == "aggregated_flows" then
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
                ifid = ifId,
                host = host_ip,
                vlans = json.encode(vlans),
                http_prefix = ntop.getHttpPrefix(),
                is_ntop_enterprise_m = ntop.isEnterpriseM(),
                aggregation_criteria = "application_protocol",
                draw = 0,
                sort = "flows",
                order = "desc",
                start = 0,
                length = 10,
                csrf = ntop.getRandomCSRFValue()
            }

            local json_context = json.encode(context)
            template.render("pages/vue_page.template", { vue_page_name = "PageAggregatedLiveFlows", page_context = json_context })
        elseif (ntop.isnEdge()) then
            print [[
      <div id="table-flows"></div>
         <script>
   var url_update = "]]

            local page_params = {
                application = _GET["application"],
                category = _GET["category"],
                alert_type = _GET["alert_type"],
                alert_type_severity = _GET["alert_type_severity"],
                tcp_flow_state = _GET["tcp_flow_state"],
                flowhosts_type = _GET["flowhosts_type"],
                traffic_type = _GET["traffic_type"],
                version = _GET["version"],
                l4proto = _GET["l4proto"],
                host = hostinfo2hostkey(host),
                tskey = _GET["tskey"],
                host_pool_id = _GET["host_pool_id"],
                talking_with = _GET["talking_with"]
            }

            print(getPageUrl(ntop.getHttpPrefix() .. "/lua/get_flows_data.lua", page_params))

            print('";')

            if (ifstats.vlan) then
                show_vlan = true
            else
                show_vlan = false
            end
            local active_flows_msg = i18n("flows_page.active_flows", {
                filter = ""
            })
            if not interface.isPacketInterface() then
                active_flows_msg = i18n("flows_page.recently_active_flows", {
                    filter = ""
                })
            elseif interface.isPcapDumpInterface() then
                active_flows_msg = i18n("flows")
            end

            local duration_or_last_seen = prefs.flow_table_time
            local begin_epoch_set = (ntop.getPref("ntopng.prefs.first_seen_set") == "1")

            local active_flows_msg = getFlowsTableTitle()

            print [[
            $("#table-flows").datatable({
            url: url_update,
            buttons: [ ]]
            printActiveFlowsDropdown("host_details.lua?page=flows", page_params, interface.getStats(),
                interface.getActiveFlowsStats(hostinfo2hostkey(host_info), nil, nil, page_params["talking_with"] or nil))
            print [[ ],
            tableCallback: function()  {
               ]]
            initFlowsRefreshRows()
            print [[
            },
            showPagination: true,
                  ]]

            print('title: "' .. active_flows_msg .. '",')

            -- Set the preference table
            preference = tablePreferences("rows_number", _GET["perPage"])
            if (preference ~= "") then
                print('perPage: ' .. preference .. ",\n")
            end

            local alignment_c_info = 'center'
            if (ntop.isnEdge()) then
                alignment_c_info = 'nowrap'
            end
            print('sort: [ ["' .. getDefaultTableSort("flows") .. '","' .. getDefaultTableSortOrder("flows") ..
                      '"] ],\n')

            print [[
      columns: [
         {
            title: "",
            field: "key",
            hidden: true,
         }, {
            title: "",
            field: "hash_id",
            hidden: true,
         }, {
            title: "",
            field: "column_key",
            css: {
               textAlign: ']]print(alignment_c_info)print[['
            }
         }, {
            title: "]]
            print(i18n("application"))
            print [[",
            field: "column_ndpi",
            sortable: true,
            css: {
               textAlign: 'center'
            }
         }, {
            title: "]]
            print(i18n("protocol"))
            print [[",
            field: "column_proto_l4",
            sortable: true,
            css: {
               textAlign: 'center'
            }
         },
           ]]

            if (show_vlan) then
                print('{ title: "' .. i18n("vlan") .. '",\n')
                print [[
            field: "column_vlan",
            sortable: true,
                    css: {
                 textAlign: 'center'
              }
            },
                   ]]
            end
            print [[
         {
            title: "]]
            print(i18n("client"))
            print [[",
            field: "column_client",
            sortable: true,
         }, {
                 title: "]]
            print(i18n("server"))
            print [[",
            field: "column_server",
            sortable: true,
         },
           ]]
            if begin_epoch_set == true then
                print [[
                 {
                    title: "]]
                print(i18n("first_seen"))
                print [[",
                    field: "column_first_seen",
                    sortable: true,
                    css: {
                            whiteSpace: 'nowrap',
                       textAlign: 'center',
                    }
                 },
              ]]
            end

            if duration_or_last_seen == false then
                print [[
                 {
                    title: "]]
                print(i18n("duration"))
                print [[",
                    field: "column_duration",
                    sortable: true,
                    css: {
                            whiteSpace: 'nowrap',
                       textAlign: 'center',
                    }
                 },
              ]]
            else
                print [[
                 {
                    title: "]]
                print(i18n("last_seen"))
                print [[",
                    field: "column_last_seen",
                    sortable: true,
                    css: {
                            whiteSpace: 'nowrap',
                       textAlign: 'center',
                    }
                 },
              ]]
            end

            print [[{
        title: "]]
            print(i18n("score"))
            print [[",
            field: "column_score",
            hidden: ]]
            print(ternary(isScoreEnabled(), "false", "true"))
            print [[,
            sortable: true,
        css: {
           textAlign: 'center'
          }
          },
        {
        title: "]]
            print(i18n("breakdown"))
            print [[",
            field: "column_breakdown",
            sortable: false,
        css: {
           textAlign: 'center'
          }
          },
        {
        title: "]]
            print(i18n("flows_page.actual_throughput"))
            print [[",
            field: "column_thpt",
            sortable: true,
        css: {
           textAlign: 'right'
        }
            },
        {
        title: "]]
            print(i18n("flows_page.total_bytes"))
            print [[",
            field: "column_bytes",
            sortable: true,
        css: {
           textAlign: 'right'
        }
            }
        ,{
        title: "]]
            print(i18n("info"))
            print [[",
            field: "column_info",
            sortable: true,
        css: {
           textAlign: 'left'
        }
            }
        ]
           });
           ]]

            if (have_nedge) then
                printBlockFlowJs()
            end

            print [[

          </script>
      ]]
        else
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
                is_pcap = interface.isPcapDumpInterface()
            })
            template.render("pages/vue_page.template", { vue_page_name = "PageFlowsList", page_context = json_context })
        end

        print [[
            </div>

   </div>]]
    elseif (page == "flows_sankey") then
        print(template.gen("pages/sankey_host.template", {
            host = host_ip,
            is_local = host["localhost"]
        }))

    elseif (page == "snmp" and ntop.isEnterpriseM() and isAllowedSystemInterface()) then
        local snmp_config = require "snmp_config"
        local snmp_devices = snmp_config.get_all_configured_devices()

        if snmp_devices[host_ip] == nil then -- host has not been configured
            if not has_snmp_location then
                local msg = i18n("snmp_page.not_configured_as_snmp_device_message", {
                    host_ip = host_ip
                })
                msg = msg .. " " .. i18n("snmp_page.guide_snmp_page_message", {
                    url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmpdevices_stats.lua"
                })

                print("<div class='alert alert-info'><i class='fas fa-info-circle fa-lg' aria-hidden='true'></i> " ..
                          msg .. "</div>")
            end
        else
            local snmp_cached_dev = require "snmp_cached_dev"
            local snmp_ui_system = require "snmp_ui_system"
            local cached_device = snmp_cached_dev:create(host_ip)
            snmp_ui_system.print_snmp_device_system_table(cached_device)
        end

        if has_snmp_location then
            print [[<table class="table table-bordered table-striped">]]
            snmp_location.print_host_snmp_localization_table_entry(host["mac"])
            print [[</table>]]
        end
    elseif (page == "processes") then
        local ebpf_utils = require "ebpf_utils"
        ebpf_utils.draw_processes_graph(host_info)
    elseif page == "geomap" then
        local context = {
            ifid = interface.getId()
        }
        
        local json_context = json.encode(context)
        
        template.render("pages/vue_page.template", {
            vue_page_name = "PageGeoMap",
            page_context = json_context
        })
    elseif (page == "contacts") then

        if (num > 0) then
            mode = "embed"
            name = host_label
            dofile(dirs.installdir .. "/scripts/lua/hosts_interaction.lua")

            print("<table class=\"table table-bordered table-striped\">\n")
            print("<tr><th width=50%>" .. i18n("contacts_page.client_contacts_initiator") .. "</th><th width=50%>" ..
                      i18n("contacts_page.server_contacts_receiver") .. "</th></tr>\n")

            print("<tr>")

            if (cnum == 0) then
                print("<td>" .. i18n("contacts_page.no_client_contacts_so_far") .. "</td>")
            else
                print("<td><table class=\"table table-bordered table-striped\">\n")
                print("<tr><th width=75%>" .. i18n("contacts_page.server_address") .. "</th><th>" ..
                          i18n("contacts_page.contacts") .. "</th></tr>\n")

                -- TOFIX VLAN (We need to remove the host vlan and add the client vlan)
                -- Client
                sortTable = {}
                for k, v in pairs(host["contacts"]["client"]) do

                    sortTable[v] = k
                end

                num = 0
                max_num = 64 -- Do not create huge maps
                for _v, k in pairsByKeys(sortTable, rev) do

                    if (num >= max_num) then
                        break
                    end
                    num = num + 1
                    name = interface.getHostInfo(k)

                    -- TOFIX VLAN (We need to remove the host vlan and add the client vlan)
                    v = host["contacts"]["client"][k]
                    info = interface.getHostInfo(k)

                    if (info ~= nil) then
                        if (info["name"] ~= nil) then
                            n = info["name"]
                        else
                            n = hostinfo2label(info)
                        end
                        url = hostinfo2detailshref(info, nil, n)
                    else
                        url = k
                    end

                    if (info ~= nil) then
                        url = url .. getFlag(info["country"]) .. " "
                    end
                    -- print(v.."<br>")
                    print("<tr><th>" .. url .. "</th><td class=\"text-end\">" .. formatValue(v) .. "</td></tr>\n")
                end
                print("</table></td>\n")
            end

            if (snum == 0) then
                print("<td>" .. i18n("contacts_page.no_server_contacts_so_far") .. "</td>")
            else
                print("<td><table class=\"table table-bordered table-striped\">\n")
                print("<tr><th width=75%>" .. i18n("contacts_page.client_address") .. "</th><th>" ..
                          i18n("contacts_page.contacts") .. "</th></tr>\n")

                -- Server
                sortTable = {}
                for k, v in pairs(host["contacts"]["server"]) do
                    sortTable[v] = k
                end

                for _v, k in pairsByKeys(sortTable, rev) do
                    v = host["contacts"]["server"][k]
                    info = interface.getHostInfo(k)
                    if (info ~= nil) then
                        if (info["name"] ~= nil) then
                            n = info["name"]
                        else
                            n = hostinfo2label(info)
                        end
                        url = hostinfo2detailshref(info, nil, n)
                    else
                        url = k
                    end

                    if (info ~= nil) then
                        url = url .. getFlag(info["country"]) .. " "
                    end
                    print("<tr><th>" .. url .. "</th><td class=\"text-end\">" .. formatValue(v) .. "</td></tr>\n")
                end
                print("</table></td>\n")
            end

            print("</tr>\n")

            print("</table>\n")
        else
            print(i18n("contacts_page.no_contacts_message"))
        end

    elseif (page == "quotas" and ntop.isnEdge() and ntop.isEnterpriseM() and host_pool_id ~=
        host_pools_instance.DEFAULT_POOL_ID and ifstats.inline) then
        local page_params = {
            ifid = ifId,
            pool = host_pool_id,
            host = hostkey,
            page = page
        }
        host_pools_nedge.printQuotas(host_pool_id, host, page_params)

    elseif (page == "periodicity_map") then
        dofile(dirs.installdir .. "/scripts/lua/inc/periodicity_map.lua")

    elseif (page == "config") then
        local context = {
            ifid = tonumber(getSystemInterfaceId()),
            csrf = ntop.getRandomCSRFValue()
        }
        local json_context = json.encode(context)
        template.render("pages/vue_page.template", {
            vue_page_name = "PageHostConfig",
            page_context = json_context
        })
    elseif (page == "historical") then
        local source_value_object = {
            ifid = interface.getId()
        }
        graph_utils.drawNewGraphs(source_value_object)
    elseif (page == "traffic_report") then
        package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/?.lua;" .. package.path
        local traffic_report = require "traffic_report"

        traffic_report.generate_traffic_report(tskey)
    end
end

if (not only_historical) and (host ~= nil) and (page ~= "traffic") and (page ~= "historical") then
    print [[
   <script>

   $(document).ready(function() {
      $("#myTable").tablesorter();
   });

  ]]
    print("var last_pkts_sent = " .. host["packets.sent"] .. ";\n")
    print("var last_pkts_rcvd = " .. host["packets.rcvd"] .. ";\n")
    print("var last_num_alerts = " .. host["num_alerts"] .. ";\n")
    print("var last_client_score = " .. host["score.as_client"] .. ";\n")
    print("var last_server_score = " .. host["score.as_server"] .. ";\n")
    print("var last_num_flow_alerts = " .. host["active_alerted_flows"] .. ";\n")
    print("var last_active_flows_as_server = " .. host["active_flows.as_server"] .. ";\n")
    print("var last_active_flows_as_client = " .. host["active_flows.as_client"] .. ";\n")
    print("var last_num_unidirectional_ingress_flows = " .. host.num_unidirectional_tcp_flows.num_ingress .. ";\n")
    print("var last_num_unidirectional_egress_flows = " .. host.num_unidirectional_tcp_flows.num_egress .. ";\n")
    print("var last_flows_as_server = " .. host["flows.as_server"] .. ";\n")
    print("var last_flows_as_client = " .. host["flows.as_client"] .. ";\n")
    print("var last_active_peers_as_server = " .. host["contacts.as_server"] .. ";\n")
    print("var last_active_peers_as_client = " .. host["contacts.as_client"] .. ";\n")
    print("var last_num_blacklisted_flows_as_server = " .. host.num_blacklisted_flows.as_server .. ";\n")
    print("var last_num_blacklisted_flows_as_client = " .. host.num_blacklisted_flows.as_client .. ";\n")
    print("var last_alerted_flows_as_server = " .. host["alerted_flows.as_server"] .. ";\n")
    print("var last_alerted_flows_as_client = " .. host["alerted_flows.as_client"] .. ";\n")
    print("var last_unreachable_flows_as_server = " .. host["unreachable_flows.as_server"] .. ";\n")
    print("var last_unreachable_flows_as_client = " .. host["unreachable_flows.as_client"] .. ";\n")
    print("var last_num_contacted_peers_with_tcp_udp_flows_no_response = " ..
              host["num_contacted_peers_with_tcp_udp_flows_no_response"] .. ";\n")
    print("var last_num_incoming_peers_that_sent_tcp_udp_flows_no_response = " ..
              host["num_incoming_peers_that_sent_tcp_udp_flows_no_response"] .. ";\n")
    print("var last_sent_tcp_retransmissions = " .. host["tcpPacketStats.sent"]["retransmissions"] .. ";\n")
    print("var last_sent_tcp_ooo = " .. host["tcpPacketStats.sent"]["out_of_order"] .. ";\n")
    print("var last_sent_tcp_lost = " .. host["tcpPacketStats.sent"]["lost"] .. ";\n")
    print("var last_sent_tcp_keep_alive = " .. host["tcpPacketStats.sent"]["keep_alive"] .. ";\n")
    print("var last_rcvd_tcp_retransmissions = " .. host["tcpPacketStats.rcvd"]["retransmissions"] .. ";\n")
    print("var last_rcvd_tcp_ooo = " .. host["tcpPacketStats.rcvd"]["out_of_order"] .. ";\n")
    print("var last_rcvd_tcp_lost = " .. host["tcpPacketStats.rcvd"]["lost"] .. ";\n")
    print("var last_rcvd_tcp_keep_alive = " .. host["tcpPacketStats.rcvd"]["keep_alive"] .. ";\n")

    if ntop.isnEdge() then
        print("var last_dropped_flows = " .. (host["flows.dropped"] or 0) .. ";\n")
    end

    if (host["dns"] ~= nil) then
        print("var last_dns_sent_num_queries = " .. host["dns"]["sent"]["num_queries"] .. ";\n")
        print("var last_dns_sent_num_replies_ok = " .. host["dns"]["sent"]["num_replies_ok"] .. ";\n")
        print("var last_dns_sent_num_replies_error = " .. host["dns"]["sent"]["num_replies_error"] .. ";\n")
        print("var last_dns_rcvd_num_queries = " .. host["dns"]["rcvd"]["num_queries"] .. ";\n")
        print("var last_dns_rcvd_num_replies_ok = " .. host["dns"]["rcvd"]["num_replies_ok"] .. ";\n")
        print("var last_dns_rcvd_num_replies_error = " .. host["dns"]["rcvd"]["num_replies_error"] .. ";\n")
    end

    if (http ~= nil) then
        print("var last_http_query_num_get = " .. http["sender"]["query"]["num_get"] .. ";\n")
        print("var last_http_query_num_post = " .. http["sender"]["query"]["num_post"] .. ";\n")
        print("var last_http_query_num_head = " .. http["sender"]["query"]["num_head"] .. ";\n")
        print("var last_http_query_num_put = " .. http["sender"]["query"]["num_put"] .. ";\n")
        print("var last_http_query_num_other = " .. http["sender"]["query"]["num_other"] .. ";\n")
        print("var last_http_response_num_1xx = " .. http["receiver"]["response"]["num_1xx"] .. ";\n")
        print("var last_http_response_num_2xx = " .. http["receiver"]["response"]["num_2xx"] .. ";\n")
        print("var last_http_response_num_3xx = " .. http["receiver"]["response"]["num_3xx"] .. ";\n")
        print("var last_http_response_num_4xx = " .. http["receiver"]["response"]["num_4xx"] .. ";\n")
        print("var last_http_response_num_5xx = " .. http["receiver"]["response"]["num_5xx"] .. ";\n")
    end

    print [[
   var host_details_interval = window.setInterval(function() {
             $.ajax({
                       type: 'GET',
                       url: ']]
    print(ntop.getHttpPrefix())
    print [[/lua/host_stats.lua',
                       data: { ifid: "]]
    print(ifId .. "")
    print('", ' .. hostinfo2json(host_info))
    print [[ },
                       /* error: function(content) { alert("]]
    print(i18n("mac_details.json_error_inactive", {
        product = info["product"]
    }))
    print [["); }, */
                       success: function(content) {
         if(content == "\"{}\"") {
             var e = document.getElementById('host_purged');
             e.style.display = "block";
         } else {
                           var host = jQuery.parseJSON(content);
                        var http = host.http;

                           $('#first_seen').html(NtopUtils.epoch2Seen(host["seen.first"]));
                           $('#last_seen').html(NtopUtils.epoch2Seen(host["seen.last"]));
                           $('#pkts_sent').html(NtopUtils.formatPackets(host["packets.sent"]));
                           $('#pkts_rcvd').html(NtopUtils.formatPackets(host["packets.rcvd"]));
                           $('#bytes_sent').html(NtopUtils.bytesToVolume(host["bytes.sent"]));
                           $('#bytes_rcvd').html(NtopUtils.bytesToVolume(host["bytes.rcvd"]));

                           $('#score_as_client').html(NtopUtils.addCommas(host["score.as_client"]));
                           $('#score_as_server').html(NtopUtils.addCommas(host["score.as_server"]));

                           $('#pkt_retransmissions_sent').html(NtopUtils.formatPackets(host["tcpPacketStats.sent"]["retransmissions"]));
                           $('#pkt_ooo_sent').html(NtopUtils.formatPackets(host["tcpPacketStats.sent"]["out_of_order"]));
                           $('#pkt_lost_sent').html(NtopUtils.formatPackets(host["tcpPacketStats.sent"]["lost"]));
                           $('#pkt_keep_alive_sent').html(NtopUtils.formatPackets(host["tcpPacketStats.sent"]["keep_alive"]));

                           $('#pkt_retransmissions_rcvd').html(NtopUtils.formatPackets(host["tcpPacketStats.rcvd"]["retransmissions"]));
                           $('#pkt_ooo_rcvd').html(NtopUtils.formatPackets(host["tcpPacketStats.rcvd"]["out_of_order"]));
                           $('#pkt_lost_rcvd').html(NtopUtils.formatPackets(host["tcpPacketStats.rcvd"]["lost"]));
                           $('#pkt_keep_alive_rcvd').html(NtopUtils.formatPackets(host["tcpPacketStats.rcvd"]["keep_alive"]));

                           if(!host["name"]) {
                              $('#name').html(host["ip"]);
                           } else {
                              $('#name').html(host["name"]);
                           }
                           $('#num_alerts').html(host["num_alerts"]);
                           $('#score').html(host["score"]);
                           $('#num_flow_alerts').html(host["active_alerted_flows"]);
                           $('#active_flows_as_client').html(NtopUtils.addCommas(host["active_flows.as_client"]));
                           $('#active_flows_as_server').html(NtopUtils.addCommas(host["active_flows.as_server"]));
                           $('#active_peers_as_client').html(NtopUtils.addCommas(host["contacts.as_client"]));
                           $('#active_peers_as_server').html(NtopUtils.addCommas(host["contacts.as_server"]));
                           $('#num_blacklisted_flows_as_client').html(NtopUtils.addCommas(host.num_blacklisted_flows.as_client));
                           $('#num_blacklisted_flows_as_server').html(NtopUtils.addCommas(host.num_blacklisted_flows.as_server));
                           $('#flows_as_client').html(NtopUtils.addCommas(host["flows.as_client"]));
                        $('#alerted_flows_as_client').html(NtopUtils.addCommas(host["alerted_flows.as_client"]));
                        $('#unreachable_flows_as_client').html(NtopUtils.addCommas(host["unreachable_flows.as_client"]));
                           $('#flows_as_server').html(NtopUtils.addCommas(host["flows.as_server"]));
                        $('#alerted_flows_as_server').html(NtopUtils.addCommas(host["alerted_flows.as_server"]));
                        $('#unreachable_flows_as_server').html(NtopUtils.addCommas(host["unreachable_flows.as_server"]));
                        $('#num_contacted_peers_with_tcp_udp_flows_no_response').html(NtopUtils.addCommas(host["num_contacted_peers_with_tcp_udp_flows_no_response"]));
                        $('#num_incoming_peers_that_sent_tcp_udp_flows_no_response').html(NtopUtils.addCommas(host["num_incoming_peers_that_sent_tcp_udp_flows_no_response"]));

                        let val;

                        if(host["flows.as_server"] == 0) { val = 0; } else { val = (host.num_unidirectional_tcp_flows.num_ingress * 100) / host["flows.as_server"]; }
                        $('#num_unidirectional_ingress_flows').html(NtopUtils.addCommas(host.num_unidirectional_tcp_flows.num_ingress)+ " ("+val.toFixed(1)+" %)");

                        if(host["flows.as_client"] == 0) { val = 0; } else { val = (host.num_unidirectional_tcp_flows.num_egress * 100) / host["flows.as_client"]; }
                        $('#num_unidirectional_egress_flows').html(NtopUtils.addCommas(host.num_unidirectional_tcp_flows.num_egress)+ " ("+val.toFixed(1)+" %)");
                     }]]

    if ntop.isnEdge() then
        print [[
                        if(host["flows.dropped"] > 0) {
                          if(host["flows.dropped"] == last_dropped_flows) {
                            $('#trend_bridge_dropped_flows').html("<i class=\"fas fa-minus\"></i>");
                          } else {
                            $('#trend_bridge_dropped_flows').html("<i class=\"fas fa-arrow-up\"></i>");
                          }

                          $('#bridge_dropped_flows').html(NtopUtils.addCommas(host["flows.dropped"]));

                          $('#bridge_dropped_flows_tr').show();
                          last_dropped_flows = host["flows.dropped"];
                        } else {
                          $('#bridge_dropped_flows_tr').hide();
                        }
]]
    end

    if (host["dns"] ~= nil) then
        print [[
                              $('#dns_sent_num_queries').html(NtopUtils.addCommas(host["dns"]["sent"]["num_queries"]));
                              $('#dns_sent_num_replies_ok').html(NtopUtils.addCommas(host["dns"]["sent"]["num_replies_ok"]));
                              $('#dns_sent_num_replies_error').html(NtopUtils.addCommas(host["dns"]["sent"]["num_replies_error"]));
                              $('#dns_rcvd_num_queries').html(NtopUtils.addCommas(host["dns"]["rcvd"]["num_queries"]));
                              $('#dns_rcvd_num_replies_ok').html(NtopUtils.addCommas(host["dns"]["rcvd"]["num_replies_ok"]));
                              $('#dns_rcvd_num_replies_error').html(NtopUtils.addCommas(host["dns"]["rcvd"]["num_replies_error"]));

                              if(host["dns"]["sent"]["num_queries"] == last_dns_sent_num_queries) {
                                 $('#trend_sent_num_queries').html("<i class=\"fas fa-minus\"></i>");
                              } else {
                                 last_dns_sent_num_queries = host["dns"]["sent"]["num_queries"];
                                 $('#trend_sent_num_queries').html("<i class=\"fas fa-arrow-up\"></i>");
                              }

                              if(host["dns"]["sent"]["num_replies_ok"] == last_dns_sent_num_replies_ok) {
                                 $('#trend_sent_num_replies_ok').html("<i class=\"fas fa-minus\"></i>");
                              } else {
                                 last_dns_sent_num_replies_ok = host["dns"]["sent"]["num_replies_ok"];
                                 $('#trend_sent_num_replies_ok').html("<i class=\"fas fa-arrow-up\"></i>");
                              }

                              if(host["dns"]["sent"]["num_replies_error"] == last_dns_sent_num_replies_error) {
                                 $('#trend_sent_num_replies_error').html("<i class=\"fas fa-minus\"></i>");
                              } else {
                                 last_dns_sent_num_replies_error = host["dns"]["sent"]["num_replies_error"];
                                 $('#trend_sent_num_replies_error').html("<i class=\"fas fa-arrow-up\"></i>");
                              }

                              if(host["dns"]["rcvd"]["num_queries"] == last_dns_rcvd_num_queries) {
                                 $('#trend_rcvd_num_queries').html("<i class=\"fas fa-minus\"></i>");
                              } else {
                                 last_dns_rcvd_num_queries = host["dns"]["rcvd"]["num_queries"];
                                 $('#trend_rcvd_num_queries').html("<i class=\"fas fa-arrow-up\"></i>");
                              }

                              if(host["dns"]["rcvd"]["num_replies_ok"] == last_dns_rcvd_num_replies_ok) {
                                 $('#trend_rcvd_num_replies_ok').html("<i class=\"fas fa-minus\"></i>");
                              } else {
                                 last_dns_rcvd_num_replies_ok = host["dns"]["rcvd"]["num_replies_ok"];
                                 $('#trend_rcvd_num_replies_ok').html("<i class=\"fas fa-arrow-up\"></i>");
                              }

                              if(host["dns"]["rcvd"]["num_replies_error"] == last_dns_rcvd_num_replies_error) {
                                 $('#trend_rcvd_num_replies_error').html("<i class=\"fas fa-minus\"></i>");
                              } else {
                                 last_dns_rcvd_num_replies_error = host["dns"]["rcvd"]["num_replies_error"];
                                 $('#trend_rcvd_num_replies_error').html("<i class=\"fas fa-arrow-up\"></i>");
                              }
                        ]]
    end

    if ((host ~= nil) and (http ~= nil)) then
        vh = http["virtual_hosts"]
        if (vh ~= nil) then
            num = table.len(vh)
            if (num > 0) then
                print [[
                  var last_http_val = {};
                  if((host !== undefined) && (http !== undefined)) {
                     $.each(http["virtual_hosts"], function(idx, obj) {
                         var key = idx.replace(/\./g,'___');
                         $('#'+key+'_bytes_vhost_rcvd').html(NtopUtils.bytesToVolume(obj["bytes.rcvd"])+" "+NtopUtils.get_trend(obj["bytes.rcvd"], last_http_val[key+"_rcvd"]));
                         $('#'+key+'_bytes_vhost_sent').html(NtopUtils.bytesToVolume(obj["bytes.sent"])+" "+NtopUtils.get_trend(obj["bytes.sent"], last_http_val[key+"_sent"]));
                         $('#'+key+'_num_vhost_req_serv').html(NtopUtils.addCommas(obj["xs"])+" "+NtopUtils.get_trend(obj["http.requests"], last_http_val[key+"_req_serv"]));
                         last_http_val[key+"_rcvd"] = obj["bytes.rcvd"];
                         last_http_val[key+"_sent"] = obj["bytes.sent"];
                         last_http_val[key+"_req_serv"] = obj["bytes.http_requests"];
                      });
                 }
            ]]
            end

            methods = {"get", "post", "head", "put", "other"}
            for i, method in ipairs(methods) do
                print(
                    '\t$("#http_query_num_' .. method .. '").html(NtopUtils.addCommas(http["sender"]["query"]["num_' ..
                        method .. '"]));\n')
                print('\tif(http["sender"]["query"]["num_' .. method .. '"] == last_http_query_num_' .. method ..
                          ') {\n\t$("#trend_http_query_num_' .. method ..
                          '").html(\'<i class=\"fas fa-minus\"></i>\');\n')
                print('} else {\n\tlast_http_query_num_' .. method .. ' = http["sender"]["query"]["num_' .. method ..
                          '"];$("#trend_http_query_num_' .. method ..
                          '").html(\'<i class=\"fas fa-arrow-up\"></i>\'); }\n')
            end

            retcodes = {"1xx", "2xx", "3xx", "4xx", "5xx"}
            for i, retcode in ipairs(retcodes) do
                print('\t$("#http_response_num_' .. retcode ..
                          '").html(NtopUtils.addCommas(http["receiver"]["response"]["num_' .. retcode .. '"]));\n')
                print(
                    '\tif(http["receiver"]["response"]["num_' .. retcode .. '"] == last_http_response_num_' .. retcode ..
                        ') {\n\t$("#trend_http_response_num_' .. retcode ..
                        '").html(\'<i class=\"fas fa-minus\"></i>\');\n')
                print('} else {\n\tlast_http_response_num_' .. retcode .. ' = http["receiver"]["response"]["num_' ..
                          retcode .. '"];$("#trend_http_response_num_' .. retcode ..
                          '").html(\'<i class=\"fas fa-arrow-up\"></i>\'); }\n')
            end
        end
    end

    print [[
                           /* **************************************** */

                        $('#trend_as_active_client').html(NtopUtils.drawTrend(host["active_flows.as_client"], last_active_flows_as_client, ""));
                        $('#trend_as_active_server').html(NtopUtils.drawTrend(host["active_flows.as_server"], last_active_flows_as_server, ""));
                        $('#peers_trend_as_active_client').html(NtopUtils.drawTrend(host["contacts.as_client"], last_active_peers_as_client, ""));
                        $('#peers_trend_as_active_server').html(NtopUtils.drawTrend(host["contacts.as_server"], last_active_peers_as_server, ""));
                        $('#trend_num_blacklisted_flows_as_client').html(NtopUtils.drawTrend(host.num_blacklisted_flows.as_client, last_num_blacklisted_flows_as_client, ""));
                        $('#trend_num_blacklisted_flows_as_server').html(NtopUtils.drawTrend(host.num_blacklisted_flows.as_server, last_num_blacklisted_flows_as_server, ""));
                        $('#trend_as_client').html(NtopUtils.drawTrend(host["flows.as_client"], last_flows_as_client, ""));
                        $('#trend_as_server').html(NtopUtils.drawTrend(host["flows.as_server"], last_flows_as_server, ""));
                        $('#trend_alerted_flows_as_server').html(NtopUtils.drawTrend(host["alerted_flows.as_server"], last_alerted_flows_as_server, " style=\"color: #B94A48;\""));
                        $('#trend_alerted_flows_as_client').html(NtopUtils.drawTrend(host["alerted_flows.as_client"], last_alerted_flows_as_client, " style=\"color: #B94A48;\""));
                        $('#trend_unreachable_flows_as_server').html(NtopUtils.drawTrend(host["unreachable_flows.as_server"], last_unreachable_flows_as_server, " style=\"color: #B94A48;\""));
                        $('#trend_unreachable_flows_as_client').html(NtopUtils.drawTrend(host["unreachable_flows.as_client"], last_unreachable_flows_as_client, " style=\"color: #B94A48;\""));
                        $('#num_contacted_peers_with_tcp_udp_flows_no_response_trend').html(NtopUtils.drawTrend(host["num_contacted_peers_with_tcp_udp_flows_no_response"], last_num_contacted_peers_with_tcp_udp_flows_no_response, " style=\"color: #B94A48;\""));
                        $('#num_incoming_peers_that_sent_tcp_udp_flows_no_response_trend').html(NtopUtils.drawTrend(host["num_incoming_peers_that_sent_tcp_udp_flows_no_response"], last_num_incoming_peers_that_sent_tcp_udp_flows_no_response, " style=\"color: #B94A48;\""));
                        $('#trend_num_unidirectional_ingress_flows').html(NtopUtils.drawTrend(host.num_unidirectional_tcp_flows.num_ingress, last_num_unidirectional_ingress_flows, " style=\"color: #B94A48;\""));
                        $('#trend_num_unidirectional_egress_flows').html(NtopUtils.drawTrend(host.num_unidirectional_tcp_flows.num_egress, last_num_unidirectional_egress_flows, " style=\"color: #B94A48;\""));

                        $('#alerts_trend').html(NtopUtils.drawTrend(host["num_alerts"], last_num_alerts, " style=\"color: #B94A48;\""));
                        $('#client_score_trend').html(NtopUtils.drawTrend(host["score.as_client"], last_client_score, " style=\"color: #B94A48;\""));
                        $('#server_score_trend').html(NtopUtils.drawTrend(host["score.as_server"], last_server_score, " style=\"color: #B94A48;\""));
                        $('#flow_alerts_trend').html(NtopUtils.drawTrend(host["active_alerted_flows"], last_num_flow_alerts, " style=\"color: #B94A48;\""));
                        $('#sent_trend').html(NtopUtils.drawTrend(host["packets.sent"], last_pkts_sent, ""));
                        $('#rcvd_trend').html(NtopUtils.drawTrend(host["packets.rcvd"], last_pkts_rcvd, ""));

                        $('#pkt_retransmissions_sent_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.sent"]["retransmissions"], last_sent_tcp_retransmissions, ""));
                        $('#pkt_ooo_sent_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.sent"]["out_of_order"], last_sent_tcp_ooo, ""));
                         $('#pkt_lost_sent_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.sent"]["lost"], last_sent_tcp_lost, ""));
                         $('#pkt_keep_alive_sent_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.sent"]["keep_alive"], last_sent_tcp_keep_alive, ""));

                        $('#pkt_retransmissions_rcvd_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.rcvd"]["retransmissions"], last_rcvd_tcp_retransmissions, ""));
                        $('#pkt_ooo_rcvd_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.rcvd"]["out_of_order"], last_rcvd_tcp_ooo, ""));
                         $('#pkt_lost_rcvd_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.rcvd"]["lost"], last_rcvd_tcp_lost, ""));
                         $('#pkt_keep_alive_rcvd_trend').html(NtopUtils.drawTrend(host["tcpPacketStats.rcvd"]["keep_alive"], last_rcvd_tcp_keep_alive, ""));

                           last_num_alerts = host["num_alerts"];
                           last_client_score = host["score.as_client"];
                           last_server_score = host["score.as_server"];
                           last_num_flow_alerts = host["active_alerted_flows"];
                           last_pkts_sent = host["packets.sent"];
                           last_pkts_rcvd = host["packets.rcvd"];
                           last_active_flows_as_client = host["active_flows.as_client"];
                           last_active_flows_as_server = host["active_flows.as_server"];
                           last_active_peers_as_client = host["contacts.as_client"];
                           last_active_peers_as_server = host["contacts.as_server"];
                           last_flows_as_client = host["flows.as_client"];
                           last_alerted_flows_as_server = host["alerted_flows.as_server"];
                           last_alerted_flows_as_client = host["alerted_flows.as_client"];
                           last_unreachable_flows_as_server = host["unreachable_flows.as_server"];
                           last_unreachable_flows_as_client = host["unreachable_flows.as_client"];
                           last_num_contacted_peers_with_tcp_udp_flows_no_response = host["num_contacted_peers_with_tcp_udp_flows_no_response"];
                           last_num_incoming_peers_that_sent_tcp_udp_flows_no_response = host["num_incoming_peers_that_sent_tcp_udp_flows_no_response"];
                           last_num_unidirectional_ingress_flows = host.num_unidirectional_tcp_flows.num_ingress;
                           last_num_unidirectional_egress_flows = host.num_unidirectional_tcp_flows.num_egress;
                           last_flows_as_server = host["flows.as_server"];
                           last_sent_tcp_retransmissions = host["tcpPacketStats.sent"]["retransmissions"];
                           last_sent_tcp_ooo = host["tcpPacketStats.sent"]["out_of_order"];
                           last_sent_tcp_lost = host["tcpPacketStats.sent"]["lost"];
                           last_sent_tcp_keep_alive = host["tcpPacketStats.sent"]["keep_alive"];
                           last_rcvd_tcp_retransmissions = host["tcpPacketStats.rcvd"]["retransmissions"];
                           last_rcvd_tcp_ooo = host["tcpPacketStats.rcvd"]["out_of_order"];
                           last_rcvd_tcp_lost = host["tcpPacketStats.rcvd"]["lost"];
                           last_rcvd_tcp_keep_alive = host["tcpPacketStats.rcvd"]["keep_alive"];
                     ]]

    print [[

                           /* **************************************** */

                           /*
                           $('#throughput').html(rsp.throughput);

                           var values = thptChart.text().split(",");
                           values.shift();
                           values.push(rsp.throughput_raw);
                           thptChart.text(values.join(",")).change();
                           */
                        }
                      });
                    }, 3000);

   </script>
    ]]
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
