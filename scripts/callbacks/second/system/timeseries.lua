--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" ..
                   package.path

-- do NOT include lua_utils here, it's not necessary, keep it light!
local callback_utils = require "callback_utils"
local scripts_triggers = require "scripts_triggers"

-- Toggle debug
local enable_second_debug = false
local ifnames = interface.getIfNames()
local create_rrd = scripts_triggers.isRrdInterfaceCreation()

-- ###########################################

local function interface_rrd_creation_enabled(ifid)
   return (create_rrd)
end

-- ###########################################

local ts_utils = require("ts_utils_core")
require("ts_second")

local curr_ifid = interface.getId()

-- Run this script for a minute before quitting (this reduces load on Lua VM infrastructure)
local num_runs = 60
local max_time = os.time() + 60 -- See SECOND_SCRIPT_DIR in PeriodicActivities.cpp

for i = 1, num_runs do
    local when = os.time()
    local check_view = false
    local view_id = nil
    local viewed_zmq_stats = {
        zmq_recv_flows = 0,
        zmq_rcvd_msgs = 0,
        zmq_msg_drops = 0,
        zmq_flow_coll_drops = 0,
        zmq_flow_coll_udp_drops = 0
    }

    if (ntop.isShuttingDown()) then break end

    -- Note: foreachInterface calls interface.select() for each interface
    callback_utils.foreachInterface(ifnames, interface_rrd_creation_enabled,
                                    function(ifname, ifstats)
        if (enable_second_debug) then
            print("Processing " .. ifname .. " ifid: " .. ifstats.id .. "\n")
        end

        if ifstats.isView then view_id = ifstats.id end

        -- Traffic stats
        -- We check for ifstats.stats.bytes to start writing only when there's data. This
        -- prevents artificial and wrong peaks especially during the startup of ntopng.
        if ifstats.stats.bytes > 0 then
            local bps, pps
            local read_throughput = false

            if (ifstats.type == "zmq") then
                -- Check if a remote probe sent updates
                if ((os.time() - ifstats.remote_update) <= 5) then
                    pps = ifstats.remote_pps
                    bps = ifstats.remote_bps
                else
                    read_throughput = true
                end
            else
                read_throughput = true
            end

            if (read_throughput) then
                pps = ifstats.stats.throughput_pps
                bps = ifstats.stats.throughput_bps
            end

            ts_utils.append("iface:throughput_pps",
                            {ifid = ifstats.id, pps = pps}, when)
            ts_utils.append("iface:throughput_bps",
                            {ifid = ifstats.id, bps = bps}, when)
            ts_utils.append("iface:traffic",
                            {ifid = ifstats.id, bytes = ifstats.stats.bytes},
                            when)
            ts_utils.append("iface:packets", {
                ifid = ifstats.id,
                packets = ifstats.stats.packets
            }, when)
            ts_utils.append("iface:packets_vs_drops", {
                ifid = ifstats.id,
                packets = ifstats.stats.packets,
                drops = ifstats.stats.drops or 0
            }, when)

            if ifstats.has_traffic_directions then
                ts_utils.append("iface:traffic_rxtx", {
                    ifid = ifstats.id,
                    bytes_sent = ifstats.eth.egress.bytes,
                    bytes_rcvd = ifstats.eth.ingress.bytes
                }, when)
                ts_utils.append("iface:packets_rxtx", {
                    ifid = ifstats.id,
                    packets_sent = ifstats.eth.egress.packets,
                    packets_rcvd = ifstats.eth.ingress.packets
                }, when)
            end

            ts_utils.append("iface:traffic_ip", {
                ifid = ifstats.id,
                bytes_ipv4 = ifstats.eth.IPv4_bytes,
                bytes_ipv6 = ifstats.eth.IPv6_bytes
            }, when)
        end

        -- ZMQ stats (only for non-packet interfaces)
        if ifstats.zmqRecvStats then
            if not ifstats.isView then -- Exclude these TS from view interfaces, added later
                ts_utils.append("iface:zmq_recv_flows", {
                    ifid = ifstats.id,
                    flows = ifstats.zmqRecvStats.flows or 0
                }, when)
                ts_utils.append("iface:zmq_rcvd_msgs", {
                    ifid = ifstats.id,
                    msgs = ifstats.zmqRecvStats.zmq_msg_rcvd or 0
                }, when)
                ts_utils.append("iface:zmq_msg_drops", {
                    ifid = ifstats.id,
                    msgs = ifstats.zmqRecvStats.zmq_msg_drops or 0
                }, when)
                ts_utils.append("iface:zmq_flow_coll_drops", {
                    ifid = ifstats.id,
                    drops = ifstats["zmq.drops.flow_collection_drops"] or 0
                }, when)
                ts_utils.append("iface:zmq_flow_coll_udp_drops", {
                    ifid = ifstats.id,
                    drops = ifstats["zmq.drops.flow_collection_udp_socket_drops"] or
                        0
                }, when)
            end
            if ifstats.isViewed then
                -- Drop these stats in viewed_zmq_stats for the view interface
                check_view = true
                viewed_zmq_stats.zmq_recv_flows =
                    viewed_zmq_stats.zmq_recv_flows +
                        (ifstats.zmqRecvStats.flows or 0)
                viewed_zmq_stats.zmq_rcvd_msgs =
                    viewed_zmq_stats.zmq_rcvd_msgs +
                        (ifstats.zmqRecvStats.zmq_msg_rcvd or 0)
                viewed_zmq_stats.zmq_msg_drops =
                    viewed_zmq_stats.zmq_msg_drops +
                        (ifstats.zmqRecvStats.zmq_msg_drops or 0)
                viewed_zmq_stats.zmq_flow_coll_drops =
                    viewed_zmq_stats.zmq_flow_coll_drops +
                        (ifstats["zmq.drops.flow_collection_drops"] or 0)
                viewed_zmq_stats.zmq_flow_coll_udp_drops =
                    viewed_zmq_stats.zmq_flow_coll_udp_drops +
                        (ifstats["zmq.drops.flow_collection_udp_socket_drops"] or
                            0)
            end
        end

        -- Discarded probing stats
        if ifstats.discarded_probing_packets then
            ts_utils.append("iface:disc_prob_bytes", {
                ifid = ifstats.id,
                bytes = ifstats.discarded_probing_bytes
            }, when)
            ts_utils.append("iface:disc_prob_pkts", {
                ifid = ifstats.id,
                packets = ifstats.discarded_probing_packets
            }, when)
        end
    end, true --[[ update direction stats ]] )

    -- Save ZMQ stats correctly for view interfaces
    if (check_view and ntop.isPro and ntop.isPro()) then
        -- Select the view interface to ensure enqueued data goes into the right
        -- interface's queue for RRD/ClickHouse timeseries
        interface.select(view_id)
        ts_utils.append("iface:zmq_recv_flows", {
            ifid = view_id,
            flows = viewed_zmq_stats.zmq_recv_flows or 0
        }, when)
        ts_utils.append("iface:zmq_rcvd_msgs", {
            ifid = view_id,
            msgs = viewed_zmq_stats.zmq_rcvd_msgs or 0
        }, when)
        ts_utils.append("iface:zmq_msg_drops", {
            ifid = view_id,
            msgs = viewed_zmq_stats.zmq_msg_drops or 0
        }, when)
        ts_utils.append("iface:zmq_flow_coll_drops", {
            ifid = view_id,
            drops = viewed_zmq_stats.zmq_flow_coll_drops or 0
        }, when)
        ts_utils.append("iface:zmq_flow_coll_udp_drops", {
            ifid = view_id,
            drops = viewed_zmq_stats.zmq_flow_coll_udp_drops or 0
        }, when)
    end

    if (ntop.isShuttingDown() or (os.time() > max_time)) then break end

    if (num_runs > 1) then ntop.msleep(1000) end
end

interface.select(curr_ifid)

-- Uncomment this to simulate slow downs
-- os.execute('perl -e "select(undef,undef,undef,0.8);"')
