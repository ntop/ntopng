--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "label_utils"
require "http_lint"
require "lua_utils_get"
require "flow_utils"
local tcp_flow_state_utils = require("tcp_flow_state_utils")
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local rest_utils = require "rest_utils"

local ifstats = interface.getStats()
local host = _GET["host"]
local talking_with = _GET["talkingWith"]
local client = _GET["client"]
local server = _GET["server"]
local flow_info = _GET["flow_info"]
local flowstats = interface.getActiveFlowsStats(host, nil, false, talking_with, client, server, flow_info)
local selected_ip = _GET["flowhosts_type"]

local rsp = {}

if interface.isView() then
    local interfaces_filter = {{
        key = "interface_filter",
        value = "",
        label = i18n("all")
    }}

    local interfaces = interface.getIfNames()
    if table.len(interfaces) > 1 then
        for id, _ in pairsByValues(interfaces, asc) do
            if tonumber(id) ~= interface.getId() then
                interfaces_filter[#interfaces_filter + 1] = {
                    key = "interface_filter",
                    value = id,
                    label = getInterfaceName(id)
                }
            end
        end
    end

    rsp[#rsp + 1] = {
        action = "interface_filter",
        label = i18n("if_stats_config.target_exporter_device_ifid"),
        name = "interface_filter",
        value = interfaces_filter
    }
end

if selected_ip then
    local hosts_type_filters = {{
        key = "flowhosts_type",
        value = selected_ip,
        label = selected_ip
    }}
    
    rsp[#rsp + 1] = {
        action = "flowhosts_type",
        label = i18n("db_explorer.host_data"),
        name = "flowhosts_type",
        value = hosts_type_filters
    }

end

if not host then
    local hosts_type_filters = {{
        key = "flowhosts_type",
        value = "",
        label = i18n("all")
    }}

    if not isEmptyString(selected_ip) then
        local newFilter = {{
            key = "flowhosts_type",
            value = "",
            label = i18n("all")
        },{
            key = "flowhosts_type",
            value = selected_ip,
            label = selected_ip
        }}

        table.insert(hosts_type_filters, newFilter)
    end

    local hosts_type_filters2 = {{
        key = "flowhosts_type",
        value = "ip_version_4",
        label = i18n("flows_page.ipv4_only"),
        group = i18n("flows_page.ip_version")
    }, {
        key = "flowhosts_type",
        value = "ip_version_6",
        label = i18n("flows_page.ipv6_only"),
        group = i18n("flows_page.ip_version")
    }, {
        key = "flowhosts_type",
        value = "local_only",
        label = i18n("flows_page.local_only"),
        group = i18n("db_search.traffic_direction")
    }, {
        key = "flowhosts_type",
        value = "remote_only",
        label = i18n("flows_page.remote_only"),
        group = i18n("db_search.traffic_direction")
    }, {
        key = "flowhosts_type",
        value = "local_origin_remote_target",
        label = i18n("flows_page.local_cli_remote_srv"),
        group = i18n("db_search.traffic_direction")
    }, {
        key = "flowhosts_type",
        value = "remote_origin_local_target",
        label = i18n("flows_page.local_srv_remote_cli"),
        group = i18n("db_search.traffic_direction")
    }}

    hosts_type_filters = table.merge(hosts_type_filters, hosts_type_filters2)

    rsp[#rsp + 1] = {
        action = "flowhosts_type",
        label = i18n("db_explorer.host_data"),
        name = "flowhosts_type",
        value = hosts_type_filters
    }
end

local protocol_filters = {{
    key = "l4proto",
    value = "",
    label = i18n("all")
}}

if flowstats["l4_protocols"] then
    local tmp_list = {}
    for key, value in pairs(flowstats["l4_protocols"], asc) do
        local num_proto = tonumber(key)
        local proto_name = l4_proto_to_string(key)

        tmp_list[proto_name] = {
            key = "l4proto",
            value = num_proto,
            label = proto_name
        }
    end

    for _, value in pairsByKeys(tmp_list, asc) do
        protocol_filters[#protocol_filters + 1] = value
    end
end

rsp[#rsp + 1] = {
    action = "l4proto",
    label = i18n("protocol"),
    name = "l4proto",
    value = protocol_filters
}

local application_filters = {{
    key = "application",
    value = "",
    label = i18n("all")
}}

local ndpicatstats = ifstats["ndpi_categories"]
local tmp_list = {}
for key, value in pairs(ndpicatstats) do
    local name = getCategoryLabel(key, value.category)
    tmp_list[name] = {
        key = "application",
        value = "cat_" .. value.category,
        label = name,
        group = i18n("category")
    }
end

for _, value in pairsByKeys(tmp_list, asc) do
    application_filters[#application_filters + 1] = value
end

for key, value in pairsByKeys(flowstats["ndpi"], asc) do
    application_filters[#application_filters + 1] = {
        key = "application",
        value = interface.getnDPIProtoId(key),
        label = key,
        group = i18n("protocol")
    }
end

rsp[#rsp + 1] = {
    action = "application",
    label = i18n("application"),
    name = "application",
    value = application_filters
}

if not isEmptyString(host) then
    local talking_with = {{
        key = "talking_with",
        value = "",
        label = i18n("all")
    }}
    tmp_list = {}
    for talk_to_host, num_flows in pairs(flowstats["talking_with"] or {}) do
        if talk_to_host ~= host then
            local hinfo = hostkey2hostinfo(talk_to_host)
            local name = hostinfo2label(hinfo)
            tmp_list[name] = {
                key = "talking_with",
                value = talk_to_host,
                label = name
            }
        end
    end

    for _, value in pairsByKeys(tmp_list, asc) do
        talking_with[#talking_with + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "talking_with",
        label = i18n("flows_page.talking_with"),
        name = "talking_with",
        value = talking_with
    }
end

if not isEmptyString(_GET["port"]) then
    local port_filters = {{
        key = "port",
        value = "",
        label = i18n("all")
    }}
    port_filters[#port_filters + 1] = {
        key = "port",
        value = _GET["port"],
        label = _GET["port"]
    }

    rsp[#rsp + 1] = {
        action = "port",
        label = i18n("port"),
        name = "port",
        value = port_filters
    }
end

local status_filters = {{
    key = "alert_type",
    value = "",
    label = i18n("all")
}, {
    key = "alert_type",
    value = "normal",
    label = i18n("flows_page.normal")
}, {
    key = "alert_type",
    value = "alerted",
    label = i18n("flows_page.all_alerted")
}, {
    key = "alert_type",
    value = "periodic",
    label = i18n("flows_page.all_periodic")
}}

local severity_stats = flowstats["alert_levels"]
for s, severity_details in pairsByField(alert_consts.severity_groups, "severity_group_id", asc) do
    if severity_stats[s] and severity_stats[s] > 0 then
        status_filters[#status_filters + 1] = {
            group = i18n('severity'),
            key = "alert_type",
            value = s,
            label = (i18n(severity_details.i18n_title) or s) .. " (" .. format_utils.formatValue(severity_stats[s]) ..
                ")"
        }
    end
end

tmp_list = {}
for status_key, status in pairs(flowstats["status"]) do
    if status.count > 0 then
        local name = alert_consts.alertTypeLabel(status_key, true --[[ no html --]] )
        tmp_list[name] = {
            group = i18n('flow_details.alerted_flows'),
            key = "alert_type",
            value = status_key,
            label = name .. " (" .. format_utils.formatValue(status.count) .. ")"
        }
    end
end

for _, value in pairsByKeys(tmp_list, asc) do
    status_filters[#status_filters + 1] = value
end

rsp[#rsp + 1] = {
    action = "alert_type",
    label = i18n("status"),
    name = "alert_type",
    value = status_filters
}

local tcp_state_filters = {{
    key = "tcp_flow_state",
    value = "",
    label = i18n("all")
}}
for _, entry in pairs({"connecting", "closed", "established", "reset"}) do
    tcp_state_filters[#tcp_state_filters + 1] = {
        key = "tcp_flow_state",
        value = entry,
        label = tcp_flow_state_utils.state2i18n(entry)
    }
end

rsp[#rsp + 1] = {
    action = "tcp_flow_state",
    label = i18n("tcp_flow_state"),
    name = "tcp_flow_state",
    value = tcp_state_filters
}

local traffic_filters = {{
    key = "traffic_type",
    value = "",
    label = i18n("all")
}, {
    key = "traffic_type",
    value = "unicast",
    label = i18n("flows_page.non_multicast")
}, {
    key = "traffic_type",
    value = "broadcast_multicast",
    label = i18n("flows_page.multicast")
}, {
    key = "traffic_type",
    value = "one_way_unicast",
    label = i18n("flows_page.one_way_non_multicast")
}, {
    key = "traffic_type",
    value = "one_way_broadcast_multicast",
    label = i18n("flows_page.one_way_multicast")
}}

rsp[#rsp + 1] = {
    action = "traffic_type",
    label = i18n("traffic_type"),
    name = "traffic_type",
    value = traffic_filters
}

local vlans = interface.getVLANsList()
if vlans then
    local vlan_filters = {{
        key = "vlan",
        value = "",
        label = i18n("all")
    }}
    for _, vlan in pairs(vlans.VLANs) do
        local vlan_name = tostring(getFullVlanName(vlan["vlan_id"]))
        if isEmptyString(vlan_name) then
            vlan_name = i18n('no_vlan')
        end
        vlan_filters[#vlan_filters + 1] = {
            key = "vlan",
            value = vlan["vlan_id"],
            label = vlan_name
        }
    end

    rsp[#rsp + 1] = {
        action = "vlan",
        label = i18n("flows_page.vlan"),
        name = "vlan",
        value = vlan_filters
    }
end

-- Host pools
local host_pools = require "host_pools"
local host_pools_instance = host_pools:create()
local pools = host_pools_instance:get_all_pools()
if (table.len(pools) > 1) then
    tmp_list = {}
    local pool_filters = {{
        key = "host_pool_id",
        value = "",
        label = i18n("all")
    }}
    for _, pool in pairs(pools) do
        tmp_list[pool.name] = {
            key = "host_pool_id",
            value = pool.pool_id,
            label = pool.name
        }
    end

    for _, value in pairsByKeys(tmp_list, asc) do
        pool_filters[#pool_filters + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "host_pool_id",
        label = i18n("if_stats_config.add_rules_type_host_pool"),
        name = "host_pool_id",
        value = pool_filters
    }
end

local networks_stats = interface.getNetworksStats()
if table.len(networks_stats) > 1 then
    local networks_filter = {{
        key = "network",
        value = "",
        label = i18n("all")
    }}

    tmp_list = {}
    for n, local_network in pairs(networks_stats) do
        local name = getFullLocalNetworkName(local_network["network_key"])
        tmp_list[name] = {
            key = "network",
            value = local_network["network_id"],
            label = name
        }
    end

    for _, value in pairsByKeys(tmp_list, asc) do
        networks_filter[#networks_filter + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "network",
        label = i18n("flows_page.networks"),
        name = "network",
        value = networks_filter
    }
end

if ntop.isPro() and interface.isPacketInterface() == false then
    local flowdevs = interface.getFlowDevices() or {}
    local devips = getProbesName(flowdevs)
    if table.len(devips) > 0 then
        local in_out_rsp = {}
        local exporter_filters = {{
            key = "deviceIP",
            value = "",
            label = i18n("all")
        }}
        tmp_list = {}
        for _, device_list in pairs(devips or {}) do
            for dev_ip, dev_resolved_name in pairsByValues(device_list, asc) do
                local dev_name = dev_ip
                if not isEmptyString(dev_resolved_name) and dev_resolved_name ~= dev_name then
                    dev_name = dev_resolved_name
                end
                tmp_list[dev_name] = {
                    key = "deviceIP",
                    value = dev_ip,
                    label = dev_name
                }
            end
        end

        for _, value in pairsByKeys(tmp_list, asc) do
            exporter_filters[#exporter_filters + 1] = value
        end

        rsp[#rsp + 1] = {
            action = "deviceIP",
            label = i18n("flows_page.device_ip"),
            name = "deviceIP",
            value = exporter_filters
        }
    end
end

if ntop.isPro() and not isEmptyString(_GET["deviceIP"]) then
    local dev_ip = _GET["deviceIP"]
    -- Flow exporter requested
    local in_ports = {{
        key = "inIfIdx",
        value = "",
        label = i18n("all")
    }}
    local ports_table = interface.getFlowDeviceInfo(dev_ip, true --[[ Show minimal info ]] )
    
    tmp_list = {}
    for _, ports in pairs(ports_table) do
        for portidx, _ in pairsByKeys(ports, asc) do
            local name = format_portidx_name(dev_ip, portidx)
            tmp_list[name] = {
                key = "inIfIdx",
                value = portidx,
                label = name
            }
        end
    end

    for _, value in pairsByKeys(tmp_list, asc) do
        in_ports[#in_ports + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "inIfIdx",
        label = i18n("db_search.input_snmp"),
        name = "inIfIdx",
        value = in_ports,
        show_with_value = dev_ip,
        show_with_key = "deviceIP"
    }

    local out_ports = {{
        key = "outIfIdx",
        value = "",
        label = i18n("all")
    }}
    local ports_table = interface.getFlowDeviceInfo(dev_ip, false)

    tmp_list = {}
    for _, ports in pairs(ports_table) do
        for portidx, _ in pairsByKeys(ports, asc) do
            local name = format_portidx_name(dev_ip, portidx)
            tmp_list[name] = {
                key = "outIfIdx",
                value = portidx,
                label = name
            }
        end
    end

    for _, value in pairsByKeys(tmp_list, asc) do
        out_ports[#out_ports + 1] = value
    end

    rsp[#rsp + 1] = {
        action = "outIfIdx",
        label = i18n("db_search.output_snmp"),
        name = "outIfIdx",
        value = out_ports,
        show_with_value = dev_ip,
        show_with_key = "deviceIP"
    }
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
