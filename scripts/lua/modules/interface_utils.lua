--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

local interface_utils = {}

function interface_utils.get_pingable_interfaces()
    local res = {}

    local interfaces = ntop.getPingIfNames()

    for id, ifname in pairs(interfaces) do
    local custom_name = getHumanReadableInterfaceName(ifname)

    if isEmptyString(custom_name) then
        custom_name = nil
    end

    -- Note: returning in a format compatible with /lua/rest/v2/get/ntopng/interfaces.lua
    res[#res + 1] = {
        ifid = tonumber(id),
        ifname = ifname,
        name = custom_name or ifname,
        is_packet_interface = true,
        is_pcap_interface = false,
        is_zmq_interface = false,
    }
    end
    return res
    
end

-- ##############################################

local function override_stats(stats, overr_stats)
    -- override stats with the values calculated from the latest user reset
    for k, v in pairs(overr_stats or {}) do
        stats[k] = v
    end
    return stats
end

-- ##############################################

-- Lightview mode has no backend support, merging stats from all interfaces here.
-- Used by if_stats.lua and rest/v2/get/interface/lightview/data.lua
-- Returns ifstats and info with:
-- ifaces: list of interfaces
-- probes_stats: nProbe instances
-- drops: dropped flows (collector) or packets
-- update_freq: min stats update frequency (sec) of interfaces
function interface_utils.getLightViewStats(ifstats)
    local prev_ifid = interface.getId()
    local info = {
        ifaces = {},
        probes_stats = {},
        drops = 0,
        update_freq = nil
    }
    local zmq_stats = {}
    local exporters_stats = {}
    local agg_stats = {
        bytes = 0,
        packets = 0,
        drops = 0,
        num_deduplicated_flows = 0
    }
    local agg_discarded_probing = nil
    local agg_db_stats = {
        flows = 0,
        dropped_flows = 0
    }
    local agg_export_stats = {}
    local agg_anomalies = {
        num_local_hosts_anomalies = 0,
        num_remote_hosts_anomalies = 0,
        tot_num_anomalies = {
            local_hosts = 0,
            remote_hosts = 0
        }
    }
    local agg_traffic = {
        tx = 0,
        rx = 0,
        tx_pkts = 0,
        rx_pkts = 0
    }
    local has_traffic_directions = false
    local agg_alerts = {
        engaged = 0,
        dropped = 0
    }
    local agg_tcp = {
        retransmissions = 0,
        out_of_order = 0,
        lost = 0
    }
    local agg_eth = {
        ingress = { bytes = 0, packets = 0 },
        egress = { bytes = 0, packets = 0 }
    }
    local agg_remote = {
        bps = 0,
        pps = 0
    }
    local agg_zmq_counters = {
        ["zmq.num_flow_exports"] = 0,
        ["zmq.drops.export_queue_full"] = 0,
        ["zmq.drops.flow_collection_drops"] = 0,
        ["zmq.drops.flow_collection_udp_socket_drops"] = 0
    }
    local exporters_drops = 0
    local packet_drops = 0

    for interface_name, _ in pairsByKeys(interface.getIfNames() or {}) do
        interface.select(interface_name)

        local tmp = interface.getStats()
        local is_collector = (tmp.zmqRecvStats ~= nil and table.len(tmp.zmqRecvStats) > 0)

        info.ifaces[#info.ifaces + 1] = {
            id = interface.getId(),
            name = getHumanReadableInterfaceName(interface_name)
        }

        local freq = interface.getStatsUpdateFreq(tmp.id)
        if freq and (not info.update_freq or freq < info.update_freq) then
            info.update_freq = freq
        end

        if tmp.stats and tmp.stats_since_reset then
            tmp.stats = override_stats(tmp.stats, tmp.stats_since_reset)
        end
        if tmp.zmqRecvStats and tmp.zmqRecvStats_since_reset then
            tmp.zmqRecvStats = override_stats(tmp.zmqRecvStats, tmp.zmqRecvStats_since_reset)
        end

        for k, v in pairs(tmp.probes or {}) do
            info.probes_stats[k] = v
        end
        for k, v in pairs(tmp.exporters or {}) do
            if not exporters_stats[k] then
                exporters_stats[k] = {}
            end
            for key_stat, value_stat in pairs(v) do
                exporters_stats[k][key_stat] = value_stat + (exporters_stats[k][key_stat] or 0)
            end
            exporters_drops = exporters_drops + (v["num_drops"] or 0)
        end
        for k, v in pairs(tmp.zmqRecvStats or {}) do
            zmq_stats[k] = (zmq_stats[k] or 0) + v
        end

        if tmp.stats then
            agg_stats.bytes = agg_stats.bytes + (tmp.stats.bytes or 0)
            agg_stats.packets = agg_stats.packets + (tmp.stats.packets or 0)
            agg_stats.drops = agg_stats.drops + (tmp.stats.drops or 0)
            agg_stats.num_deduplicated_flows = agg_stats.num_deduplicated_flows + (tmp.stats.num_deduplicated_flows or 0)

            if not is_collector then
                packet_drops = packet_drops + (tmp.stats.drops or 0)
            end

            if tmp.stats.discarded_probing_packets then
                agg_discarded_probing = agg_discarded_probing or { packets = 0, bytes = 0 }
                agg_discarded_probing.packets = agg_discarded_probing.packets + (tmp.stats.discarded_probing_packets or 0)
                agg_discarded_probing.bytes = agg_discarded_probing.bytes + (tmp.stats.discarded_probing_bytes or 0)
            end
        end

        if tmp.dbStats then
            agg_db_stats.flows = agg_db_stats.flows + (tmp.dbStats.flows or 0)
            agg_db_stats.dropped_flows = agg_db_stats.dropped_flows + (tmp.dbStats.dropped_flows or 0)
        end

        for _, db_type in ipairs({ "db", "es", "kafka", "syslog" }) do
            local s = tmp.stats_since_reset and tmp.stats_since_reset[db_type]
            if s then
                agg_export_stats[db_type] = agg_export_stats[db_type] or {
                    flow_export_count = 0,
                    flow_export_rate = 0,
                    flow_export_drops = 0
                }
                agg_export_stats[db_type].flow_export_count = agg_export_stats[db_type].flow_export_count + (s.flow_export_count or 0)
                agg_export_stats[db_type].flow_export_rate = agg_export_stats[db_type].flow_export_rate + (s.flow_export_rate or 0)
                agg_export_stats[db_type].flow_export_drops = agg_export_stats[db_type].flow_export_drops + (s.flow_export_drops or 0)
            end
        end

        if tmp.anomalies then
            agg_anomalies.num_local_hosts_anomalies = agg_anomalies.num_local_hosts_anomalies + (tmp.anomalies.num_local_hosts_anomalies or 0)
            agg_anomalies.num_remote_hosts_anomalies = agg_anomalies.num_remote_hosts_anomalies + (tmp.anomalies.num_remote_hosts_anomalies or 0)
            local an = tmp.anomalies.tot_num_anomalies or {}
            agg_anomalies.tot_num_anomalies.local_hosts = agg_anomalies.tot_num_anomalies.local_hosts + (an.local_hosts or 0)
            agg_anomalies.tot_num_anomalies.remote_hosts = agg_anomalies.tot_num_anomalies.remote_hosts + (an.remote_hosts or 0)
        end

        if tmp.has_traffic_directions then
            has_traffic_directions = true
            agg_traffic.tx = agg_traffic.tx + (tmp.traffic_sent_since_reset or 0)
            agg_traffic.rx = agg_traffic.rx + (tmp.traffic_rcvd_since_reset or 0)
            agg_traffic.tx_pkts = agg_traffic.tx_pkts + (tmp.packets_sent_since_reset or 0)
            agg_traffic.rx_pkts = agg_traffic.rx_pkts + (tmp.packets_rcvd_since_reset or 0)
        end

        agg_alerts.engaged = agg_alerts.engaged + (tmp.num_alerts_engaged or 0)
        agg_alerts.dropped = agg_alerts.dropped + (tmp.num_dropped_alerts or 0)

        if tmp.tcpPacketStats then
            agg_tcp.retransmissions = agg_tcp.retransmissions + (tmp.tcpPacketStats.retransmissions or 0)
            agg_tcp.out_of_order = agg_tcp.out_of_order + (tmp.tcpPacketStats.out_of_order or 0)
            agg_tcp.lost = agg_tcp.lost + (tmp.tcpPacketStats.lost or 0)
        end

        if tmp.eth then
            for _, dir in ipairs({ "ingress", "egress" }) do
                if tmp.eth[dir] then
                    agg_eth[dir].bytes = agg_eth[dir].bytes + (tmp.eth[dir].bytes or 0)
                    agg_eth[dir].packets = agg_eth[dir].packets + (tmp.eth[dir].packets or 0)
                end
            end
        end

        agg_remote.bps = agg_remote.bps + (tonumber(tmp.remote_bps) or 0)
        agg_remote.pps = agg_remote.pps + (tonumber(tmp.remote_pps) or 0)

        for k, _ in pairs(agg_zmq_counters) do
            agg_zmq_counters[k] = agg_zmq_counters[k] + (tonumber(tmp[k]) or 0)
        end
    end

    interface.select(tostring(prev_ifid))

    ifstats.zmqRecvStats = zmq_stats
    ifstats.exporters = exporters_stats
    ifstats.probes = info.probes_stats
    ifstats.stats.bytes = agg_stats.bytes
    ifstats.stats.packets = agg_stats.packets
    ifstats.stats.drops = agg_stats.drops
    ifstats.stats.num_deduplicated_flows = agg_stats.num_deduplicated_flows
    ifstats.stats_since_reset.drops = agg_stats.drops

    ifstats.stats.discarded_probing_packets = agg_discarded_probing and agg_discarded_probing.packets or nil
    ifstats.stats.discarded_probing_bytes = agg_discarded_probing and agg_discarded_probing.bytes or nil

    if agg_db_stats.flows > 0 or agg_db_stats.dropped_flows > 0 then
        ifstats.dbStats = agg_db_stats
    end
    for db_type, s in pairs(agg_export_stats) do
        ifstats.stats_since_reset[db_type] = s
    end

    ifstats.anomalies = agg_anomalies
    ifstats.has_traffic_directions = has_traffic_directions
    ifstats.traffic_sent_since_reset = agg_traffic.tx
    ifstats.traffic_rcvd_since_reset = agg_traffic.rx
    ifstats.packets_sent_since_reset = agg_traffic.tx_pkts
    ifstats.packets_rcvd_since_reset = agg_traffic.rx_pkts
    ifstats.num_alerts_engaged = agg_alerts.engaged
    ifstats.num_dropped_alerts = agg_alerts.dropped
    ifstats.tcpPacketStats = agg_tcp
    ifstats.eth = ifstats.eth or {}
    ifstats.eth.ingress = ifstats.eth.ingress or {}
    ifstats.eth.egress = ifstats.eth.egress or {}
    ifstats.eth.ingress.bytes = agg_eth.ingress.bytes
    ifstats.eth.ingress.packets = agg_eth.ingress.packets
    ifstats.eth.egress.bytes = agg_eth.egress.bytes
    ifstats.eth.egress.packets = agg_eth.egress.packets
    ifstats.remote_bps = agg_remote.bps
    ifstats.remote_pps = agg_remote.pps
    for k, v in pairs(agg_zmq_counters) do
        ifstats[k] = v
    end

    -- flows when collecting, packets otherwise
    if table.len(zmq_stats) > 0 then
        info.drops = exporters_drops
    else
        info.drops = packet_drops
    end

    return ifstats, info
end

-- ##############################################

return interface_utils
