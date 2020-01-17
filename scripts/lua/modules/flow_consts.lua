--
-- (C) 2019-20 - ntop.org
--
-- This file contains the alert constats

local flow_consts = {}
local locales_utils = require "locales_utils"
local format_utils  = require "format_utils"
local os_utils = require("os_utils")
local plugins_utils = require("plugins_utils")
local plugins_consts_utils = require("plugins_consts_utils")

-- Custom User Status
flow_consts.custom_status_1 = 59
flow_consts.custom_status_2 = 60
flow_consts.custom_status_3 = 61
flow_consts.custom_status_4 = 62
flow_consts.custom_status_5 = 63

-- ################################################################################

function flow_consts.getDefinititionsDir()
    local dirs = ntop.getDirs()
    return(os_utils.fixPath(plugins_utils.PLUGINS_RUNTIME_PATH .. "/status_definitions"))
end

-- ################################################################################

-- See flow_consts.resetDefinitions()
flow_consts.status_types = {}
local status_by_id = {}
local status_key_by_id = {}
local status_by_prio = {}
local max_prio = 0

local function loadStatusDefs()
    if(false) then
      if(string.find(debug.traceback(), "second.lua")) then
         traceError(TRACE_WARNING, TRACE_CONSOLE, "second.lua is loading flow_consts.lua. This will slow it down!")
      end
    end

    local defs_dirs = {flow_consts.getDefinititionsDir()}

    if ntop.isPro() then
      defs_dirs[#defs_dirs + 1] = flow_consts.getDefinititionsDir() .. "/pro"
    end

    flow_consts.resetDefinitions()

    for _, defs_dir in pairs(defs_dirs) do
        for fname in pairs(ntop.readdir(defs_dir)) do
            if ends(fname, ".lua") then
                local mod_fname = string.sub(fname, 1, string.len(fname) - 4)
                local full_path = os_utils.fixPath(defs_dir .. "/" .. fname)
                local def_script = dofile(full_path)

                if(def_script == nil) then
                    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Error loading status definition from %s", full_path))
                    goto next_script
                end

                flow_consts.loadDefinition(def_script, mod_fname, full_path)
            end

            ::next_script::
        end
    end
end

-- ################################################################################

function flow_consts.resetDefinitions()
   flow_consts.status_types = {}
   status_by_id = {}
   status_key_by_id = {}
   status_by_prio = {}
   max_prio = 0
end

-- ################################################################################

function flow_consts.loadDefinition(def_script, mod_fname, script_path)
    local required_fields = {"prio", "alert_severity", "alert_type", "i18n_title"}

    -- print("Loading "..script_path.."\n")
    
    -- Check the required fields
    for _, k in pairs(required_fields) do
        if(def_script[k] == nil) then
            traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Missing required field '%s' in %s", k, script_path))
            return(false)
        end
    end

    -- local def_id = tonumber(def_script.status_id)
    local def_id = plugins_consts_utils.get_assigned_id("flow", mod_fname)

    if(def_id == nil) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s: missing status ID %d", script_path, def_id))
        return(false)
    end

    if(status_by_id[def_id] ~= nil) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s: status ID %d redefined, skipping", script_path, def_id))
        return(false)
    end

    if(status_by_prio[def_script.prio] ~= nil) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("%s: status priority must be unique, skipping", script_path))
        return(false)
    end

    -- Success
    def_script.status_id = def_id
    status_by_id[def_id] = def_script
    status_key_by_id[def_id] = mod_fname
    max_prio = math.max(max_prio, def_script.prio)
    status_by_prio[def_script.prio] = def_script
    flow_consts.status_types[mod_fname] = def_script

    return(true)
end

-- ################################################################################

function flow_consts.getStatusDescription(status_id, flowstatus_info)
    local status_def = status_by_id[tonumber(status_id)]

    if(status_def == nil) then
        return(i18n("flow_details.unknown_status",{status=status}))
    end

    if(type(status_def.i18n_description) == "function") then
        -- formatter function
        return(status_def.i18n_description(flowstatus_info))
    elseif(status_def.i18n_description ~= nil) then
        return(i18n(status_def.i18n_description) or status_def.i18n_description)
    else
        return(i18n(status_def.i18n_title) or status_def.i18n_title)
    end
end

-- ################################################################################

function flow_consts.getStatusTitle(status_id)
    local status_def = status_by_id[tonumber(status_id)]

    if(status_def == nil) then
        return(i18n("flow_details.unknown_status",{status=status}))
    end

    return(i18n(status_def.i18n_title))
end

-- ################################################################################

function flow_consts.getStatusInfo(status_id)
    return(status_by_id[tonumber(status_id)])
end

-- ################################################################################

function flow_consts.getStatusType(status_id)
    return(status_key_by_id[tonumber(status_id)])
end

-- ################################################################################

-- @brief Calculate the predominant status from a status bitmap
function flow_consts.getPredominantStatus(status_bitmap)
    local normal_status = flow_consts.status_types.status_normal

    if(status_bitmap == normal_status.status_id) then
        -- Simple case: normal status
        return(normal_status)
    end

    -- Look for predominant status in descending order to speed up search
    for i = max_prio,0,-1 do
        local status = status_by_prio[i]

        if(status and ntop.bitmapIsSet(status_bitmap, status.status_id)) then
            return(status)
        end
    end
end

-- ################################################################################

-- IMPORTANT: keep it in sync with ParserInterface::ParserInterface()

flow_consts.flow_fields_description = {
    ["IN_BYTES"] = i18n("flow_fields_description.in_bytes"),
    ["IN_PKTS"] = i18n("flow_fields_description.in_pkts"),
    ["PROTOCOL"] = i18n("flow_fields_description.protocol"),
    ["PROTOCOL_MAP"] = i18n("flow_fields_description.protocol_map"),
    ["SRC_TOS"] = i18n("flow_fields_description.src_tos"),
    ["TCP_FLAGS"] = i18n("flow_fields_description.tcp_flags"),
    ["L4_SRC_PORT"] = i18n("flow_fields_description.l4_src_port"),
    ["L4_SRC_PORT_MAP"] = i18n("flow_fields_description.l4_src_port_map"),
    ["IPV4_SRC_ADDR"] = i18n("flow_fields_description.ipv4_src_addr"),
    ["IPV4_SRC_MASK"] = i18n("flow_fields_description.ipv4_src_mask"),
    ["INPUT_SNMP"] = i18n("flow_fields_description.input_snmp"),
    ["L4_DST_PORT"] = i18n("flow_fields_description.l4_dst_port"),
    ["L4_DST_PORT_MAP"] = i18n("flow_fields_description.l4_dst_port_map"),
    ["L4_SRV_PORT"] = i18n("flow_fields_description.l4_srv_port"),
    ["L4_SRV_PORT_MAP"] = i18n("flow_fields_description.l4_srv_port_map"),
    ["IPV4_DST_ADDR"] = i18n("flow_fields_description.ipv4_dst_addr"),
    ["IPV4_DST_MASK"] = i18n("flow_fields_description.ipv4_dst_mask"),
    ["OUTPUT_SNMP"] = i18n("flow_fields_description.output_snmp"),
    ["IPV4_NEXT_HOP"] = i18n("flow_fields_description.ipv4_next_hop"),
    ["SRC_AS"] = i18n("flow_fields_description.src_as"),
    ["DST_AS"] = i18n("flow_fields_description.dst_as"),
    ["LAST_SWITCHED"] = i18n("flow_fields_description.last_switched"),
    ["FIRST_SWITCHED"] = i18n("flow_fields_description.first_switched"),
    ["OUT_BYTES"] = i18n("flow_fields_description.out_bytes"),
    ["OUT_PKTS"] = i18n("flow_fields_description.out_pkts"),
    ["IPV6_SRC_ADDR"] = i18n("flow_fields_description.ipv6_src_addr"),
    ["IPV6_DST_ADDR"] = i18n("flow_fields_description.ipv6_dst_addr"),
    ["IPV6_SRC_MASK"] = i18n("flow_fields_description.ipv6_src_mask"),
    ["IPV6_DST_MASK"] = i18n("flow_fields_description.ipv6_dst_mask"),
    ["ICMP_TYPE"] = i18n("flow_fields_description.icmp_type"),
    ["SAMPLING_INTERVAL"] = i18n("flow_fields_description.sampling_interval"),
    ["SAMPLING_ALGORITHM"] = i18n("flow_fields_description.sampling_algorithm"),
    ["FLOW_ACTIVE_TIMEOUT"] = i18n("flow_fields_description.flow_active_timeout"),
    ["FLOW_INACTIVE_TIMEOUT"] = i18n("flow_fields_description.flow_inactive_timeout"),
    ["ENGINE_TYPE"] = i18n("flow_fields_description.engine_type"),
    ["ENGINE_ID"] = i18n("flow_fields_description.engine_id"),
    ["TOTAL_BYTES_EXP"] = i18n("flow_fields_description.total_bytes_exp"),
    ["TOTAL_PKTS_EXP"] = i18n("flow_fields_description.total_pkts_exp"),
    ["TOTAL_FLOWS_EXP"] = i18n("flow_fields_description.total_flows_exp"),
    ["MIN_TTL"] = i18n("flow_fields_description.min_ttl"),
    ["MAX_TTL"] = i18n("flow_fields_description.max_ttl"),
    ["DST_TOS"] = i18n("flow_fields_description.dst_tos"),
    ["IN_SRC_MAC"] = i18n("flow_fields_description.in_src_mac"),
    ["OUT_SRC_MAC"] = i18n("flow_fields_description.out_src_mac"),
    ["SRC_VLAN"] = i18n("flow_fields_description.src_vlan"),
    ["DST_VLAN"] = i18n("flow_fields_description.dst_vlan"),
    ["DOT1Q_SRC_VLAN"] = i18n("flow_fields_description.dot1q_src_vlan"),
    ["DOT1Q_DST_VLAN"] = i18n("flow_fields_description.dot1q_dst_vlan"),
    ["IP_PROTOCOL_VERSION"] = i18n("flow_fields_description.ip_protocol_version"),
    ["DIRECTION"] = i18n("flow_fields_description.direction"),
    ["IPV6_NEXT_HOP"] = i18n("flow_fields_description.ipv6_next_hop"),
    ["MPLS_LABEL_1"] = i18n("flow_fields_description.mpls_label_1"),
    ["MPLS_LABEL_2"] = i18n("flow_fields_description.mpls_label_2"),
    ["MPLS_LABEL_3"] = i18n("flow_fields_description.mpls_label_3"),
    ["MPLS_LABEL_4"] = i18n("flow_fields_description.mpls_label_4"),
    ["MPLS_LABEL_5"] = i18n("flow_fields_description.mpls_label_5"),
    ["MPLS_LABEL_6"] = i18n("flow_fields_description.mpls_label_6"),
    ["MPLS_LABEL_7"] = i18n("flow_fields_description.mpls_label_7"),
    ["MPLS_LABEL_8"] = i18n("flow_fields_description.mpls_label_8"),
    ["MPLS_LABEL_9"] = i18n("flow_fields_description.mpls_label_9"),
    ["MPLS_LABEL_10"] = i18n("flow_fields_description.mpls_label_10"),
    ["IN_DST_MAC"] = i18n("flow_fields_description.in_dst_mac"),
    ["OUT_DST_MAC"] = i18n("flow_fields_description.out_dst_mac"),
    ["APPLICATION_ID"] = i18n("flow_fields_description.application_id"),
    ["PACKET_SECTION_OFFSET"] = i18n("flow_fields_description.packet_section_offset"),
    ["SAMPLED_PACKET_SIZE"] = i18n("flow_fields_description.sampled_packet_size"),
    ["SAMPLED_PACKET_ID"] = i18n("flow_fields_description.sampled_packet_id"),
    ["EXPORTER_IPV4_ADDRESS"] = i18n("flow_fields_description.exporter_ipv4_address"),
    ["EXPORTER_IPV6_ADDRESS"] = i18n("flow_fields_description.exporter_ipv6_address"),
    ["FLOW_END_REASON"] = i18n("flow_fields_description.flow_end_reason"),
    ["FLOW_ID"] = i18n("flow_fields_description.flow_id"),
    ["FLOW_START_SEC"] = i18n("flow_fields_description.flow_start_sec"),
    ["FLOW_END_SEC"] = i18n("flow_fields_description.flow_end_sec"),
    ["FLOW_START_MILLISECONDS"] = i18n("flow_fields_description.flow_start_milliseconds"),
    ["FLOW_START_MICROSECONDS"] = i18n("flow_fields_description.flow_start_microseconds"),
    ["FLOW_END_MILLISECONDS"] = i18n("flow_fields_description.flow_end_milliseconds"),
    ["FLOW_END_MICROSECONDS"] = i18n("flow_fields_description.flow_end_microseconds"),
    ['FIREWALL_EVENT'] = i18n("flow_fields_description.firewall_event"),
    ["BIFLOW_DIRECTION"] = i18n("flow_fields_description.biflow_direction"),
    ["INGRESS_VRFID"] = i18n("flow_fields_description.ingress_vrfid"),
    ["FLOW_DURATION_MILLISECONDS"] = i18n("flow_fields_description.flow_duration_milliseconds"),
    ["FLOW_DURATION_MICROSECONDS"] = i18n("flow_fields_description.flow_duration_microseconds"),
    ["ICMP_IPV4_TYPE"] = i18n("flow_fields_description.icmp_ipv4_type"),
    ["ICMP_IPV4_CODE"] = i18n("flow_fields_description.icmp_ipv4_code"),
    ["POST_NAT_SRC_IPV4_ADDR"] = i18n("flow_fields_description.post_nat_src_ipv4_addr"),
    ["POST_NAT_DST_IPV4_ADDR"] = i18n("flow_fields_description.post_nat_dst_ipv4_addr"),
    ["POST_NAPT_SRC_TRANSPORT_PORT"] = i18n("flow_fields_description.post_napt_src_transport_port"),
    ["POST_NAPT_DST_TRANSPORT_PORT"] = i18n("flow_fields_description.post_napt_dst_transport_port"),
    ["OBSERVATION_POINT_TYPE"] = i18n("flow_fields_description.observation_point_type"),
    ["OBSERVATION_POINT_ID"] = i18n("flow_fields_description.observation_point_id"),
    ["SELECTOR_ID"] = i18n("flow_fields_description.selector_id"),
    ["IPFIX_SAMPLING_ALGORITHM"] = i18n("flow_fields_description.ipfix_sampling_algorithm"),
    ["SAMPLING_SIZE"] = i18n("flow_fields_description.sampling_size"),
    ["SAMPLING_POPULATION"] = i18n("flow_fields_description.sampling_population"),
    ["FRAME_LENGTH"] = i18n("flow_fields_description.frame_length"),
    ["PACKETS_OBSERVED"] = i18n("flow_fields_description.packets_observed"),
    ["PACKETS_SELECTED"] = i18n("flow_fields_description.packets_selected"),
    ["SELECTOR_NAME"] = i18n("flow_fields_description.selector_name"),
    ["APPLICATION_NAME"] = i18n("flow_fields_description.application_name"),
    ["USER_NAME"] = i18n("flow_fields_description.user_name"),
    ["SRC_FRAGMENTS"] = i18n("flow_fields_description.src_fragments"),
    ["DST_FRAGMENTS"] = i18n("flow_fields_description.dst_fragments"),
    ["CLIENT_NW_LATENCY_MS"] = i18n("flow_fields_description.client_nw_latency_ms"),
    ["SERVER_NW_LATENCY_MS"] = i18n("flow_fields_description.server_nw_latency_ms"),
    ["APPL_LATENCY_MS"] = i18n("flow_fields_description.appl_latency_ms"),
    ["NPROBE_IPV4_ADDRESS"] = i18n("flow_fields_description.nprobe_ipv4_address"),
    ["SRC_TO_DST_MAX_THROUGHPUT"] = i18n("flow_fields_description.src_to_dst_max_throughput"),
    ["SRC_TO_DST_MIN_THROUGHPUT"] = i18n("flow_fields_description.src_to_dst_min_throughput"),
    ["SRC_TO_DST_AVG_THROUGHPUT"] = i18n("flow_fields_description.src_to_dst_avg_throughput"),
    ["DST_TO_SRC_MAX_THROUGHPUT"] = i18n("flow_fields_description.dst_to_src_max_throughput"),
    ["DST_TO_SRC_MIN_THROUGHPUT"] = i18n("flow_fields_description.dst_to_src_min_throughput"),
    ["DST_TO_SRC_AVG_THROUGHPUT"] = i18n("flow_fields_description.dst_to_src_avg_throughput"),
    ["NUM_PKTS_UP_TO_128_BYTES"] = i18n("flow_fields_description.num_pkts_up_to_128_bytes"),
    ["NUM_PKTS_128_TO_256_BYTES"] = i18n("flow_fields_description.num_pkts_128_to_256_bytes"),
    ["NUM_PKTS_256_TO_512_BYTES"] = i18n("flow_fields_description.num_pkts_256_to_512_bytes"),
    ["NUM_PKTS_512_TO_1024_BYTES"] = i18n("flow_fields_description.num_pkts_512_to_1024_bytes"),
    ["NUM_PKTS_1024_TO_1514_BYTES"] = i18n("flow_fields_description.num_pkts_1024_to_1514_bytes"),
    ["NUM_PKTS_OVER_1514_BYTES"] = i18n("flow_fields_description.num_pkts_over_1514_bytes"),
    ["CUMULATIVE_ICMP_TYPE"] = i18n("flow_fields_description.cumulative_icmp_type"),
    ["SRC_IP_COUNTRY"] = i18n("flow_fields_description.src_ip_country"),
    ["SRC_IP_CITY"] = i18n("flow_fields_description.src_ip_city"),
    ["DST_IP_COUNTRY"] = i18n("flow_fields_description.dst_ip_country"),
    ["DST_IP_CITY"] = i18n("flow_fields_description.dst_ip_city"),
    ["SRC_IP_LONG"] = i18n("flow_fields_description.src_ip_long"),
    ["SRC_IP_LAT"] = i18n("flow_fields_description.src_ip_lat"),
    ["DST_IP_LONG"] = i18n("flow_fields_description.dst_ip_long"),
    ["DST_IP_LAT"] = i18n("flow_fields_description.dst_ip_lat"),
    ["FLOW_PROTO_PORT"] = i18n("flow_fields_description.flow_proto_port"),
    ["UPSTREAM_TUNNEL_ID"] = i18n("flow_fields_description.upstream_tunnel_id"),
    ["UPSTREAM_SESSION_ID"] = i18n("flow_fields_description.upstream_session_id"),
    ["LONGEST_FLOW_PKT"] = i18n("flow_fields_description.longest_flow_pkt"),
    ["SHORTEST_FLOW_PKT"] = i18n("flow_fields_description.shortest_flow_pkt"),
    ["RETRANSMITTED_IN_BYTES"] = i18n("flow_fields_description.retransmitted_in_bytes"),
    ["RETRANSMITTED_IN_PKTS"] = i18n("flow_fields_description.retransmitted_in_pkts"),
    ["RETRANSMITTED_OUT_BYTES"] = i18n("flow_fields_description.retransmitted_out_bytes"),
    ["RETRANSMITTED_OUT_PKTS"] = i18n("flow_fields_description.retransmitted_out_pkts"),
    ["OOORDER_IN_PKTS"] = i18n("flow_fields_description.ooorder_in_pkts"),
    ["OOORDER_OUT_PKTS"] = i18n("flow_fields_description.ooorder_out_pkts"),
    ["UNTUNNELED_PROTOCOL"] = i18n("flow_fields_description.untunneled_protocol"),
    ["UNTUNNELED_IPV4_SRC_ADDR"] = i18n("flow_fields_description.untunneled_ipv4_src_addr"),
    ["UNTUNNELED_L4_SRC_PORT"] = i18n("flow_fields_description.untunneled_l4_src_port"),
    ["UNTUNNELED_IPV4_DST_ADDR"] = i18n("flow_fields_description.untunneled_ipv4_dst_addr"),
    ["UNTUNNELED_L4_DST_PORT"] = i18n("flow_fields_description.untunneled_l4_dst_port"),
    ["L7_PROTO"] = i18n("flow_fields_description.l7_proto"),
    ["L7_PROTO_NAME"] = i18n("flow_fields_description.l7_proto_name"),
    ["DOWNSTREAM_TUNNEL_ID"] = i18n("flow_fields_description.downstream_tunnel_id"),
    ["DOWNSTREAM_SESSION_ID"] = i18n("flow_fields_description.downstream_session_id"),
    ["SSL_SERVER_NAME"] = i18n("flow_fields_description.tls_server_name"),
    ["BITTORRENT_HASH"] = i18n("flow_fields_description.bittorrent_hash"),
    ["FLOW_USER_NAME"] = i18n("flow_fields_description.flow_user_name"),
    ["FLOW_SERVER_NAME"] = i18n("flow_fields_description.flow_server_name"),
    ["PLUGIN_NAME"] = i18n("flow_fields_description.plugin_name"),
    ["UNTUNNELED_IPV6_SRC_ADDR"] = i18n("flow_fields_description.untunneled_ipv6_src_addr"),
    ["UNTUNNELED_IPV6_DST_ADDR"] = i18n("flow_fields_description.untunneled_ipv6_dst_addr"),
    ["NUM_PKTS_TTL_EQ_1"] = i18n("flow_fields_description.num_pkts_ttl_eq_1"),
    ["NUM_PKTS_TTL_2_5"] = i18n("flow_fields_description.num_pkts_ttl_2_5"),
    ["NUM_PKTS_TTL_5_32"] = i18n("flow_fields_description.num_pkts_ttl_5_32"),
    ["NUM_PKTS_TTL_32_64"] = i18n("flow_fields_description.num_pkts_ttl_32_64"),
    ["NUM_PKTS_TTL_64_96"] = i18n("flow_fields_description.num_pkts_ttl_64_96"),
    ["NUM_PKTS_TTL_96_128"] = i18n("flow_fields_description.num_pkts_ttl_96_128"),
    ["NUM_PKTS_TTL_128_160"] = i18n("flow_fields_description.num_pkts_ttl_128_160"),
    ["NUM_PKTS_TTL_160_192"] = i18n("flow_fields_description.num_pkts_ttl_160_192"),
    ["NUM_PKTS_TTL_192_224"] = i18n("flow_fields_description.num_pkts_ttl_192_224"),
    ["NUM_PKTS_TTL_224_255"] = i18n("flow_fields_description.num_pkts_ttl_224_255"),
    ["IN_SRC_OSI_SAP"] = i18n("flow_fields_description.in_src_osi_sap"),
    ["OUT_DST_OSI_SAP"] = i18n("flow_fields_description.out_dst_osi_sap"),
    ["DURATION_IN"] = i18n("flow_fields_description.duration_in"),
    ["DURATION_OUT"] = i18n("flow_fields_description.duration_out"),
    ["TCP_WIN_MIN_IN"] = i18n("flow_fields_description.tcp_win_min_in"),
    ["TCP_WIN_MAX_IN"] = i18n("flow_fields_description.tcp_win_max_in"),
    ["TCP_WIN_MSS_IN"] = i18n("flow_fields_description.tcp_win_mss_in"),
    ["TCP_WIN_SCALE_IN"] = i18n("flow_fields_description.tcp_win_scale_in"),
    ["TCP_WIN_MIN_OUT"] = i18n("flow_fields_description.tcp_win_min_out"),
    ["TCP_WIN_MAX_OUT"] = i18n("flow_fields_description.tcp_win_max_out"),
    ["TCP_WIN_MSS_OUT"] = i18n("flow_fields_description.tcp_win_mss_out"),
    ["TCP_WIN_SCALE_OUT"] = i18n("flow_fields_description.tcp_win_scale_out"),
    ["PAYLOAD_HASH"] = i18n("flow_fields_description.payload_hash"),
    ["SRC_AS_MAP"] = i18n("flow_fields_description.src_as_map"),
    ["DST_AS_MAP"] = i18n("flow_fields_description.dst_as_map"),

    -- BGP Update Listener
    ["SRC_AS_PATH_1"] = i18n("flow_fields_description.src_as_path_1"),
    ["SRC_AS_PATH_2"] = i18n("flow_fields_description.src_as_path_2"),
    ["SRC_AS_PATH_3"] = i18n("flow_fields_description.src_as_path_3"),
    ["SRC_AS_PATH_4"] = i18n("flow_fields_description.src_as_path_4"),
    ["SRC_AS_PATH_5"] = i18n("flow_fields_description.src_as_path_5"),
    ["SRC_AS_PATH_6"] = i18n("flow_fields_description.src_as_path_6"),
    ["SRC_AS_PATH_7"] = i18n("flow_fields_description.src_as_path_7"),
    ["SRC_AS_PATH_8"] = i18n("flow_fields_description.src_as_path_8"),
    ["SRC_AS_PATH_9"] = i18n("flow_fields_description.src_as_path_9"),
    ["SRC_AS_PATH_10"] = i18n("flow_fields_description.src_as_path_10"),
    ["DST_AS_PATH_1"] = i18n("flow_fields_description.dst_as_path_1"),
    ["DST_AS_PATH_2"] = i18n("flow_fields_description.dst_as_path_2"),
    ["DST_AS_PATH_3"] = i18n("flow_fields_description.dst_as_path_3"),
    ["DST_AS_PATH_4"] = i18n("flow_fields_description.dst_as_path_4"),
    ["DST_AS_PATH_5"] = i18n("flow_fields_description.dst_as_path_5"),
    ["DST_AS_PATH_6"] = i18n("flow_fields_description.dst_as_path_6"),
    ["DST_AS_PATH_7"] = i18n("flow_fields_description.dst_as_path_7"),
    ["DST_AS_PATH_8"] = i18n("flow_fields_description.dst_as_path_8"),
    ["DST_AS_PATH_9"] = i18n("flow_fields_description.dst_as_path_9"),
    ["DST_AS_PATH_10"] = i18n("flow_fields_description.dst_as_path_10"),

    -- DHCP Protocol
    ["DHCP_CLIENT_MAC"] = i18n("flow_fields_description.dhcp_client_mac"),
    ["DHCP_CLIENT_IP"] = i18n("flow_fields_description.dhcp_client_ip"),
    ["DHCP_CLIENT_NAME"] = i18n("flow_fields_description.dhcp_client_name"),
    ["DHCP_REMOTE_ID"] = i18n("flow_fields_description.dhcp_remote_id"),
    ["DHCP_SUBSCRIBER_ID"] = i18n("flow_fields_description.dhcp_subscriber_id"),
    ["DHCP_MESSAGE_TYPE"] = i18n("flow_fields_description.dhcp_message_type"),

    -- Diameter Protocol
    ["DIAMETER_REQ_MSG_TYPE"] = i18n("flow_fields_description.diameter_req_msg_type"),
    ["DIAMETER_RSP_MSG_TYPE"] = i18n("flow_fields_description.diameter_rsp_msg_type"),
    ["DIAMETER_REQ_ORIGIN_HOST"] = i18n("flow_fields_description.diameter_req_origin_host"),
    ["DIAMETER_RSP_ORIGIN_HOST"] = i18n("flow_fields_description.diameter_rsp_origin_host"),
    ["DIAMETER_REQ_USER_NAME"] = i18n("flow_fields_description.diameter_req_user_name"),
    ["DIAMETER_RSP_RESULT_CODE"] = i18n("flow_fields_description.diameter_rsp_result_code"),
    ["DIAMETER_EXP_RES_VENDOR_ID"] = i18n("flow_fields_description.diameter_exp_res_vendor_id"),
    ["DIAMETER_EXP_RES_RESULT_CODE"] = i18n("flow_fields_description.diameter_exp_res_result_code"),
    ["DIAMETER_HOP_BY_HOP_ID"] = i18n("flow_fields_description.diameter_hop_by_hop_id"),
    ["DIAMETER_CLR_CANCEL_TYPE"] = i18n("flow_fields_description.diameter_clr_cancel_type"),
    ["DIAMETER_CLR_FLAGS"] = i18n("flow_fields_description.diameter_clr_flags"),

    -- DNS/LLMNR Protocol
    ["DNS_QUERY"] = i18n("flow_fields_description.dns_query"),
    ["DNS_QUERY_ID"] = i18n("flow_fields_description.dns_query_id"),
    ["DNS_QUERY_TYPE"] = i18n("flow_fields_description.dns_query_type"),
    ["DNS_RET_CODE"] = i18n("flow_fields_description.dns_ret_code"),
    ["DNS_NUM_ANSWERS"] = i18n("flow_fields_description.dns_num_answers"),
    ["DNS_TTL_ANSWER"] = i18n("flow_fields_description.dns_ttl_answer"),
    ["DNS_RESPONSE"] = i18n("flow_fields_description.dns_response"),
    ["DNS_TX_ID"] = i18n("flow_fields_description.dns_tx_id"),

    -- FTP Protocol
    ["FTP_LOGIN"] = i18n("flow_fields_description.ftp_login"),
    ["FTP_PASSWORD"] = i18n("flow_fields_description.ftp_password"),
    ["FTP_COMMAND"] = i18n("flow_fields_description.ftp_command"),
    ["FTP_COMMAND_RET_CODE"] = i18n("flow_fields_description.ftp_command_ret_code"),

    -- GTPv0 Signaling Protocol
    ["GTPV0_REQ_MSG_TYPE"] = i18n("flow_fields_description.gtpv0_req_msg_type"),
    ["GTPV0_RSP_MSG_TYPE"] = i18n("flow_fields_description.gtpv0_rsp_msg_type"),
    ["GTPV0_TID"] = i18n("flow_fields_description.gtpv0_tid"),
    ["GTPV0_APN_NAME"] = i18n("flow_fields_description.gtpv0_apn_name"),
    ["GTPV0_END_USER_IP"] = i18n("flow_fields_description.gtpv0_end_user_ip"),
    ["GTPV0_END_USER_MSISDN"] = i18n("flow_fields_description.gtpv0_end_user_msisdn"),
    ["GTPV0_RAI_MCC"] = i18n("flow_fields_description.gtpv0_rai_mcc"),
    ["GTPV0_RAI_MNC"] = i18n("flow_fields_description.gtpv0_rai_mnc"),
    ["GTPV0_RAI_CELL_LAC"] = i18n("flow_fields_description.gtpv0_rai_cell_lac"),
    ["GTPV0_RAI_CELL_RAC"] = i18n("flow_fields_description.gtpv0_rai_cell_rac"),
    ["GTPV0_RESPONSE_CAUSE"] = i18n("flow_fields_description.gtpv0_response_cause"),

    -- GTPv1 Signaling Protocol
    ["GTPV1_REQ_MSG_TYPE"] = i18n("flow_fields_description.gtpv1_req_msg_type"),
    ["GTPV1_RSP_MSG_TYPE"] = i18n("flow_fields_description.gtpv1_rsp_msg_type"),
    ["GTPV1_C2S_TEID_DATA"] = i18n("flow_fields_description.gtpv1_c2s_teid_data"),
    ["GTPV1_C2S_TEID_CTRL"] = i18n("flow_fields_description.gtpv1_c2s_teid_ctrl"),
    ["GTPV1_S2C_TEID_DATA"] = i18n("flow_fields_description.gtpv1_s2c_teid_data"),
    ["GTPV1_S2C_TEID_CTRL"] = i18n("flow_fields_description.gtpv1_s2c_teid_ctrl"),
    ["GTPV1_END_USER_IP"] = i18n("flow_fields_description.gtpv1_end_user_ip"),
    ["GTPV1_END_USER_IMSI"] = i18n("flow_fields_description.gtpv1_end_user_imsi"),
    ["GTPV1_END_USER_MSISDN"] = i18n("flow_fields_description.gtpv1_end_user_msisdn"),
    ["GTPV1_END_USER_IMEI"] = i18n("flow_fields_description.gtpv1_end_user_imei"),
    ["GTPV1_APN_NAME"] = i18n("flow_fields_description.gtpv1_apn_name"),
    ["GTPV1_RAT_TYPE"] = i18n("flow_fields_description.gtpv1_rat_type"),
    ["GTPV1_RAI_MCC"] = i18n("flow_fields_description.gtpv1_rai_mcc"),
    ["GTPV1_RAI_MNC"] = i18n("flow_fields_description.gtpv1_rai_mnc"),
    ["GTPV1_RAI_LAC"] = i18n("flow_fields_description.gtpv1_rai_lac"),
    ["GTPV1_RAI_RAC"] = i18n("flow_fields_description.gtpv1_rai_rac"),
    ["GTPV1_ULI_MCC"] = i18n("flow_fields_description.gtpv1_uli_mcc"),
    ["GTPV1_ULI_MNC"] = i18n("flow_fields_description.gtpv1_uli_mnc"),
    ["GTPV1_ULI_CELL_LAC"] = i18n("flow_fields_description.gtpv1_uli_cell_lac"),
    ["GTPV1_ULI_CELL_CI"] = i18n("flow_fields_description.gtpv1_uli_cell_ci"),
    ["GTPV1_ULI_SAC"] = i18n("flow_fields_description.gtpv1_uli_sac"),
    ["GTPV1_RESPONSE_CAUSE"] = i18n("flow_fields_description.gtpv1_response_cause"),

    -- GTPv2 Signaling Protocol
    ["GTPV2_REQ_MSG_TYPE"] = i18n("flow_fields_description.gtpv2_req_msg_type"),
    ["GTPV2_RSP_MSG_TYPE"] = i18n("flow_fields_description.gtpv2_rsp_msg_type"),
    ["GTPV2_C2S_S1U_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_c2s_s1u_gtpu_teid"),
    ["GTPV2_C2S_S1U_GTPU_IP"] = i18n("flow_fields_description.gtpv2_c2s_s1u_gtpu_ip"),
    ["GTPV2_S2C_S1U_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_s2c_s1u_gtpu_teid"),
    ["GTPV2_S5_S8_GTPC_TEID"] = i18n("flow_fields_description.gtpv2_s5_s8_gtpc_teid"),
    ["GTPV2_S2C_S1U_GTPU_IP"] = i18n("flow_fields_description.gtpv2_s2c_s1u_gtpu_ip"),
    ["GTPV2_C2S_S5_S8_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_gtpu_teid"),
    ["GTPV2_S2C_S5_S8_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_gtpu_teid"),
    ["GTPV2_C2S_S5_S8_GTPU_IP"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_gtpu_ip"),
    ["GTPV2_S2C_S5_S8_GTPU_IP"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_gtpu_ip"),
    ["GTPV2_END_USER_IMSI"] = i18n("flow_fields_description.gtpv2_end_user_imsi"),
    ["GTPV2_END_USER_MSISDN"] = i18n("flow_fields_description.gtpv2_end_user_msisdn"),
    ["GTPV2_APN_NAME"] = i18n("flow_fields_description.gtpv2_apn_name"),
    ["GTPV2_ULI_MCC"] = i18n("flow_fields_description.gtpv2_uli_mcc"),
    ["GTPV2_ULI_MNC"] = i18n("flow_fields_description.gtpv2_uli_mnc"),
    ["GTPV2_ULI_CELL_TAC"] = i18n("flow_fields_description.gtpv2_uli_cell_tac"),
    ["GTPV2_ULI_CELL_ID"] = i18n("flow_fields_description.gtpv2_uli_cell_id"),
    ["GTPV2_RESPONSE_CAUSE"] = i18n("flow_fields_description.gtpv2_response_cause"),
    ["GTPV2_RAT_TYPE"] = i18n("flow_fields_description.gtpv2_rat_type"),
    ["GTPV2_PDN_IP"] = i18n("flow_fields_description.gtpv2_pdn_ip"),
    ["GTPV2_END_USER_IMEI"] = i18n("flow_fields_description.gtpv2_end_user_imei"),
    ["GTPV2_C2S_S5_S8_GTPC_IP"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_gtpc_ip"),
    ["GTPV2_S2C_S5_S8_GTPC_IP"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_gtpc_ip"),
    ["GTPV2_C2S_S5_S8_SGW_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_sgw_gtpu_teid"),
    ["GTPV2_S2C_S5_S8_SGW_GTPU_TEID"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_sgw_gtpu_teid"),
    ["GTPV2_C2S_S5_S8_SGW_GTPU_IP"] = i18n("flow_fields_description.gtpv2_c2s_s5_s8_sgw_gtpu_ip"),
    ["GTPV2_S2C_S5_S8_SGW_GTPU_IP"] = i18n("flow_fields_description.gtpv2_s2c_s5_s8_sgw_gtpu_ip"),

    -- HTTP Protocol
    ["HTTP_URL"] = i18n("flow_fields_description.http_url"),
    ["HTTP_METHOD"] = i18n("flow_fields_description.http_method"),
    ["HTTP_RET_CODE"] = i18n("flow_fields_description.http_ret_code"),
    ["HTTP_REFERER"] = i18n("flow_fields_description.http_referer"),
    ["HTTP_UA"] = i18n("flow_fields_description.http_ua"),
    ["HTTP_MIME"] = i18n("flow_fields_description.http_mime"),
    ["HTTP_HOST"] = i18n("flow_fields_description.http_host"),
    ["HTTP_SITE"] = i18n("flow_fields_description.http_site"),
    ["HTTP_X_FORWARDED_FOR"] = i18n("flow_fields_description.http_x_forwarded_for"),
    ["HTTP_VIA"] = i18n("flow_fields_description.http_via"),
    ["HTTP_PROTOCOL"] = i18n("flow_fields_description.http_protocol"),
    ["HTTP_LENGTH"] = i18n("flow_fields_description.http_length"),

    -- IMAP Protocol
    ["IMAP_LOGIN"] = i18n("flow_fields_description.imap_login"),

    -- MySQL Plugin
    ["MYSQL_SERVER_VERSION"] = i18n("flow_fields_description.mysql_server_version"),
    ["MYSQL_USERNAME"] = i18n("flow_fields_description.mysql_username"),
    ["MYSQL_DB"] = i18n("flow_fields_description.mysql_db"),
    ["MYSQL_QUERY"] = i18n("flow_fields_description.mysql_query"),
    ["MYSQL_RESPONSE"] = i18n("flow_fields_description.mysql_response"),
    ["MYSQL_APPL_LATENCY_USEC"] = i18n("flow_fields_description.mysql_appl_latency_usec"),

    -- NETBIOS Protocol
    ["NETBIOS_QUERY_NAME"] = i18n("flow_fields_description.netbios_query_name"),
    ["NETBIOS_QUERY_TYPE"] = i18n("flow_fields_description.netbios_query_type"),
    ["NETBIOS_RESPONSE"] = i18n("flow_fields_description.netbios_response"),
    ["NETBIOS_QUERY_OS"] = i18n("flow_fields_description.netbios_query_os"),

    -- Oracle Protocol
    ["ORACLE_USERNAME"] = i18n("flow_fields_description.oracle_username"),
    ["ORACLE_QUERY"] = i18n("flow_fields_description.oracle_query"),
    ["ORACLE_RSP_CODE"] = i18n("flow_fields_description.oracle_rsp_code"),
    ["ORACLE_RSP_STRING"] = i18n("flow_fields_description.oracle_rsp_string"),
    ["ORACLE_QUERY_DURATION"] = i18n("flow_fields_description.oracle_query_duration"),

    -- OP3 Protocol
    ["POP_USER"] = i18n("flow_fields_description.pop_user"),

    -- System process information
    ["SRC_PROC_PID"] = i18n("flow_fields_description.src_proc_pid"),
    ["SRC_PROC_NAME"] = i18n("flow_fields_description.src_proc_name"),
    ["SRC_PROC_UID"] = i18n("flow_fields_description.src_proc_uid"),
    ["SRC_PROC_USER_NAME"] = i18n("flow_fields_description.src_proc_user_name"),
    ["SRC_FATHER_PROC_PID"] = i18n("flow_fields_description.src_father_proc_pid"),
    ["SRC_FATHER_PROC_NAME"] = i18n("flow_fields_description.src_father_proc_name"),
    ["SRC_PROC_ACTUAL_MEMORY"] = i18n("flow_fields_description.src_proc_actual_memory"),
    ["SRC_PROC_PEAK_MEMORY"] = i18n("flow_fields_description.src_proc_peak_memory"),
    ["SRC_PROC_AVERAGE_CPU_LOAD"] = i18n("flow_fields_description.src_proc_average_cpu_load"),
    ["SRC_PROC_NUM_PAGE_FAULTS"] = i18n("flow_fields_description.src_proc_num_page_faults"),
    ["SRC_PROC_PCTG_IOWAIT"] = i18n("flow_fields_description.src_proc_pctg_iowait"),
    ["DST_PROC_PID"] = i18n("flow_fields_description.dst_proc_pid"),
    ["DST_PROC_NAME"] = i18n("flow_fields_description.dst_proc_name"),
    ["DST_PROC_UID"] = i18n("flow_fields_description.dst_proc_uid"),
    ["DST_PROC_USER_NAME"] = i18n("flow_fields_description.dst_proc_user_name"),
    ["DST_FATHER_PROC_PID"] = i18n("flow_fields_description.dst_father_proc_pid"),
    ["DST_FATHER_PROC_NAME"] = i18n("flow_fields_description.dst_father_proc_name"),
    ["DST_PROC_ACTUAL_MEMORY"] = i18n("flow_fields_description.dst_proc_actual_memory"),
    ["DST_PROC_PEAK_MEMORY"] = i18n("flow_fields_description.dst_proc_peak_memory"),
    ["DST_PROC_AVERAGE_CPU_LOAD"] = i18n("flow_fields_description.dst_proc_average_cpu_load"),
    ["DST_PROC_NUM_PAGE_FAULTS"] = i18n("flow_fields_description.dst_proc_num_page_faults"),
    ["DST_PROC_PCTG_IOWAIT"] = i18n("flow_fields_description.dst_proc_pctg_iowait"),

    -- Radius Protocol
    ["RADIUS_REQ_MSG_TYPE"] = i18n("flow_fields_description.radius_req_msg_type"),
    ["RADIUS_RSP_MSG_TYPE"] = i18n("flow_fields_description.radius_rsp_msg_type"),
    ["RADIUS_USER_NAME"] = i18n("flow_fields_description.radius_user_name"),
    ["RADIUS_CALLING_STATION_ID"] = i18n("flow_fields_description.radius_calling_station_id"),
    ["RADIUS_CALLED_STATION_ID"] = i18n("flow_fields_description.radius_called_station_id"),
    ["RADIUS_NAS_IP_ADDR"] = i18n("flow_fields_description.radius_nas_ip_addr"),
    ["RADIUS_NAS_IDENTIFIER"] = i18n("flow_fields_description.radius_nas_identifier"),
    ["RADIUS_USER_IMSI"] = i18n("flow_fields_description.radius_user_imsi"),
    ["RADIUS_USER_IMEI"] = i18n("flow_fields_description.radius_user_imei"),
    ["RADIUS_FRAMED_IP_ADDR"] = i18n("flow_fields_description.radius_framed_ip_addr"),
    ["RADIUS_ACCT_SESSION_ID"] = i18n("flow_fields_description.radius_acct_session_id"),
    ["RADIUS_ACCT_STATUS_TYPE"] = i18n("flow_fields_description.radius_acct_status_type"),
    ["RADIUS_ACCT_IN_OCTETS"] = i18n("flow_fields_description.radius_acct_in_octets"),
    ["RADIUS_ACCT_OUT_OCTETS"] = i18n("flow_fields_description.radius_acct_out_octets"),
    ["RADIUS_ACCT_IN_PKTS"] = i18n("flow_fields_description.radius_acct_in_pkts"),
    ["RADIUS_ACCT_OUT_PKTS"] = i18n("flow_fields_description.radius_acct_out_pkts"),

    -- RTP Plugin
    ["RTP_SSRC"] = i18n("flow_fields_description.rtp_ssrc"),
    ["RTP_FIRST_SEQ"] = i18n("flow_fields_description.rtp_first_seq"),
    ["RTP_FIRST_TS"] = i18n("flow_fields_description.rtp_first_ts"),
    ["RTP_LAST_SEQ"] = i18n("flow_fields_description.rtp_last_seq"),
    ["RTP_LAST_TS"] = i18n("flow_fields_description.rtp_last_ts"),
    ["RTP_IN_JITTER"] = i18n("flow_fields_description.rtp_in_jitter"),
    ["RTP_OUT_JITTER"] = i18n("flow_fields_description.rtp_out_jitter"),
    ["RTP_IN_PKT_LOST"] = i18n("flow_fields_description.rtp_in_pkt_lost"),
    ["RTP_OUT_PKT_LOST"] = i18n("flow_fields_description.rtp_out_pkt_lost"),
    ["RTP_IN_PKT_DROP"] = i18n("flow_fields_description.rtp_in_pkt_drop"),
    ["RTP_OUT_PKT_DROP"] = i18n("flow_fields_description.rtp_out_pkt_drop"),
    ["RTP_IN_PAYLOAD_TYPE"] = i18n("flow_fields_description.rtp_in_payload_type"),
    ["RTP_OUT_PAYLOAD_TYPE"] = i18n("flow_fields_description.rtp_out_payload_type"),
    ["RTP_IN_MAX_DELTA"] = i18n("flow_fields_description.rtp_in_max_delta"),
    ["RTP_OUT_MAX_DELTA"] = i18n("flow_fields_description.rtp_out_max_delta"),
    ["RTP_SIP_CALL_ID"] = i18n("flow_fields_description.rtp_sip_call_id"),
    ["RTP_MOS"] = i18n("flow_fields_description.rtp_mos"),
    ["RTP_IN_MOS"] = i18n("flow_fields_description.rtp_in_mos"),
    ["RTP_OUT_MOS"] = i18n("flow_fields_description.rtp_out_mos"),
    ["RTP_R_FACTOR"] = i18n("flow_fields_description.rtp_r_factor"),
    ["RTP_IN_R_FACTOR"] = i18n("flow_fields_description.rtp_in_r_factor"),
    ["RTP_OUT_R_FACTOR"] = i18n("flow_fields_description.rtp_out_r_factor"),
    ["RTP_IN_TRANSIT"] = i18n("flow_fields_description.rtp_in_transit"),
    ["RTP_OUT_TRANSIT"] = i18n("flow_fields_description.rtp_out_transit"),
    ["RTP_RTT"] = i18n("flow_fields_description.rtp_rtt"),
    ["RTP_DTMF_TONES"] = i18n("flow_fields_description.rtp_dtmf_tones"),

    -- S1AP Protocol
    ["S1AP_ENB_UE_S1AP_ID"] = i18n("flow_fields_description.s1ap_enb_ue_s1ap_id"),
    ["S1AP_MME_UE_S1AP_ID"] = i18n("flow_fields_description.s1ap_mme_ue_s1ap_id"),
    ["S1AP_MSG_EMM_TYPE_MME_TO_ENB"] = i18n("flow_fields_description.s1ap_msg_emm_type_mme_to_enb"),
    ["S1AP_MSG_ESM_TYPE_MME_TO_ENB"] = i18n("flow_fields_description.s1ap_msg_esm_type_mme_to_enb"),
    ["S1AP_MSG_EMM_TYPE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_msg_emm_type_enb_to_mme"),
    ["S1AP_MSG_ESM_TYPE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_msg_esm_type_enb_to_mme"),
    ["S1AP_CAUSE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_cause_enb_to_mme"),
    ["S1AP_DETAILED_CAUSE_ENB_TO_MME"] = i18n("flow_fields_description.s1ap_detailed_cause_enb_to_mme"),

    -- SIP Plugin
    ["SIP_CALL_ID"] = i18n("flow_fields_description.sip_call_id"),
    ["SIP_CALLING_PARTY"] = i18n("flow_fields_description.sip_calling_party"),
    ["SIP_CALLED_PARTY"] = i18n("flow_fields_description.sip_called_party"),
    ["SIP_RTP_CODECS"] = i18n("flow_fields_description.sip_rtp_codecs"),
    ["SIP_INVITE_TIME"] = i18n("flow_fields_description.sip_invite_time"),
    ["SIP_TRYING_TIME"] = i18n("flow_fields_description.sip_trying_time"),
    ["SIP_RINGING_TIME"] = i18n("flow_fields_description.sip_ringing_time"),
    ["SIP_INVITE_OK_TIME"] = i18n("flow_fields_description.sip_invite_ok_time"),
    ["SIP_INVITE_FAILURE_TIME"] = i18n("flow_fields_description.sip_invite_failure_time"),
    ["SIP_BYE_TIME"] = i18n("flow_fields_description.sip_bye_time"),
    ["SIP_BYE_OK_TIME"] = i18n("flow_fields_description.sip_bye_ok_time"),
    ["SIP_CANCEL_TIME"] = i18n("flow_fields_description.sip_cancel_time"),
    ["SIP_CANCEL_OK_TIME"] = i18n("flow_fields_description.sip_cancel_ok_time"),
    ["SIP_RTP_IPV4_SRC_ADDR"] = i18n("flow_fields_description.sip_rtp_ipv4_src_addr"),
    ["SIP_RTP_L4_SRC_PORT"] = i18n("flow_fields_description.sip_rtp_l4_src_port"),
    ["SIP_RTP_IPV4_DST_ADDR"] = i18n("flow_fields_description.sip_rtp_ipv4_dst_addr"),
    ["SIP_RTP_L4_DST_PORT"] = i18n("flow_fields_description.sip_rtp_l4_dst_port"),
    ["SIP_RESPONSE_CODE"] = i18n("flow_fields_description.sip_response_code"),
    ["SIP_REASON_CAUSE"] = i18n("flow_fields_description.sip_reason_cause"),
    ["SIP_C_IP"] = i18n("flow_fields_description.sip_c_ip"),
    ["SIP_CALL_STATE"] = i18n("flow_fields_description.sip_call_state"),

    -- SMTP Protocol
    ["SMTP_MAIL_FROM"] = i18n("flow_fields_description.smtp_mail_from"),
    ["SMTP_RCPT_TO"] = i18n("flow_fields_description.smtp_rcpt_to"),

    -- SSDP Protocol
    ["SSDP_HOST"] = i18n("flow_fields_description.ssdp_host"),
    ["SSDP_USN"] = i18n("flow_fields_description.ssdp_usn"),
    ["SSDP_SERVER"] = i18n("flow_fields_description.ssdp_server"),
    ["SSDP_TYPE"] = i18n("flow_fields_description.ssdp_type"),
    ["SSDP_METHOD"] = i18n("flow_fields_description.ssdp_method"),

    -- TLS Protocol
    ["TLS_VERSION"] = i18n("flow_fields_description.tls_version"),
    ["TLS_CERT_NOT_BEFORE"] = i18n("flow_fields_description.tls_cert_not_before"),
    ["TLS_CERT_AFTER"] = i18n("flow_fields_description.tls_cert_after"),
    ["TLS_CERT_SHA1"] = i18n("flow_fields_description.tls_cert_sha1"),
    ["TLS_CERT_DN"] = i18n("flow_fields_description.tls_cert_dn"),
    ["TLS_CERT_SN"] = i18n("flow_fields_description.tls_cert_sn"),
    ["TLS_CERT_SUBJECT"] = i18n("flow_fields_description.tls_cert_subject"),

    -- File Info
    ["FILE_NAME"] = i18n("flow_fields_description.file_name"),
    ["FILE_SIZE"] = i18n("flow_fields_description.file_size"),
    ["FILE_STATE"] = i18n("flow_fields_description.file_state"),
    ["FILE_GAPS"] = i18n("flow_fields_description.file_gaps"),
    ["FILE_STORED"] = i18n("flow_fields_description.file_stored"),
    ["FILE_ID"] = i18n("flow_fields_description.file_id"),

    -- Suricata
    ["SURICATA_FLOW_ID"] = i18n("flow_fields_description.suricata_flow_id"),
    ["SURICATA_APP_PROTO"] = i18n("flow_fields_description.suricata_app_proto"),

    -- Misc
    ["COMMUNITY_ID"] = i18n("flow_fields_description.community_id"),
}

-- ################################################################################

-- http://www.itu.int/itudoc/itu-t/ob-lists/icc/e212_685.pdf
flow_consts.mobile_country_code = {
["202"] = "Greece",
["204"] = "Netherlands (Kingdom of the)",
["206"] = "Belgium",
["208"] = "France",
["212"] = "Monaco (Principality of)",
["213"] = "Andorra (Principality of)",
["214"] = "Spain",
["216"] = "Hungary (Republic of)",
["218"] = "Bosnia and Herzegovina",
["219"] = "Croatia (Republic of)",
["220"] = "Serbia and Montenegro",
["222"] = "Italy",
["225"] = "Vatican City State",
["226"] = "Romania",
["228"] = "Switzerland (Confederation of)",
["230"] = "Czech Republic",
["231"] = "Slovak Republic",
["232"] = "Austria",
["234"] = "United Kingdom",
["235"] = "United Kingdom",
["238"] = "Denmark",
["240"] = "Sweden",
["242"] = "Norway",
["244"] = "Finland",
["246"] = "Lithuania (Republic of)",
["247"] = "Latvia (Republic of)",
["248"] = "Estonia (Republic of)",
["250"] = "Russian Federation",
["255"] = "Ukraine",
["257"] = "Belarus (Republic of)",
["259"] = "Moldova (Republic of)",
["260"] = "Poland (Republic of)",
["262"] = "Germany (Federal Republic of)",
["266"] = "Gibraltar",
["268"] = "Portugal",
["270"] = "Luxembourg",
["272"] = "Ireland",
["274"] = "Iceland",
["276"] = "Albania (Republic of)",
["278"] = "Malta",
["280"] = "Cyprus (Republic of)",
["282"] = "Georgia",
["283"] = "Armenia (Republic of)",
["284"] = "Bulgaria (Republic of)",
["286"] = "Turkey",
["288"] = "Faroe Islands",
["290"] = "Greenland (Denmark)",
["292"] = "San Marino (Republic of)",
["293"] = "Slovenia (Republic of)",
["294"] = "The Former Yugoslav Republic of Macedonia",
["295"] = "Liechtenstein (Principality of)",
["302"] = "Canada",
["308"] = "Saint Pierre and Miquelon",
["310"] = "United States of America",
["311"] = "United States of America",
["312"] = "United States of America",
["313"] = "United States of America",
["314"] = "United States of America",
["315"] = "United States of America",
["316"] = "United States of America",
["330"] = "Puerto Rico",
["332"] = "United States Virgin Islands",
["334"] = "Mexico",
["338"] = "Jamaica",
["340"] = "Martinique / Guadeloupe",
["342"] = "Barbados",
["344"] = "Antigua and Barbuda",
["346"] = "Cayman Islands",
["348"] = "British Virgin Islands",
["350"] = "Bermuda",
["352"] = "Grenada",
["354"] = "Montserrat",
["356"] = "Saint Kitts and Nevis",
["358"] = "SaintLucia",
["360"] = "Saint Vincent and the Grenadines",
["362"] = "Netherlands Antilles",
["363"] = "Aruba",
["364"] = "Bahamas (Commonwealth of the)",
["365"] = "Anguilla",
["366"] = "Dominica (Commonwealth of)",
["368"] = "Cuba",
["370"] = "Dominican Republic",
["372"] = "Haiti (Republic of)",
["374"] = "Trinidad and Tobago",
["376"] = "Turks and Caicos Islands",
["400"] = "Azerbaijani Republic",
["401"] = "Kazakhstan (Republic of)",
["402"] = "Bhutan (Kingdom of)",
["404"] = "India (Republic of)",
["410"] = "Pakistan (Islamic Republic of)",
["412"] = "Afghanistan",
["413"] = "Sri Lanka (Democratic Socialist Republic of)",
["414"] = "Myanmar (Union of)",
["415"] = "Lebanon",
["416"] = "Jordan (Hashemite Kingdom of)",
["417"] = "Syrian Arab Republic",
["418"] = "Iraq (Republic of)",
["419"] = "Kuwait (State of)",
["420"] = "Saudi Arabia (Kingdom of)",
["421"] = "Yemen (Republic of)",
["422"] = "Oman (Sultanate of)",
["424"] = "United Arab Emirates",
["425"] = "Israel (State of)",
["426"] = "Bahrain (Kingdom of)",
["427"] = "Qatar (State of)",
["428"] = "Mongolia",
["429"] = "Nepal",
["430"] = "United Arab Emirates b",
["431"] = "United Arab Emirates b",
["432"] = "Iran (Islamic Republic of)",
["434"] = "Uzbekistan (Republic of)",
["436"] = "Tajikistan (Republic of)",
["437"] = "Kyrgyz Republic",
["438"] = "Turkmenistan",
["440"] = "Japan",
["441"] = "Japan",
["450"] = "Korea (Republic of)",
["452"] = "Viet Nam (Socialist Republic of)",
["454"] = "Hongkong China",
["455"] = "Macao China",
["456"] = "Cambodia (Kingdom of)",
["457"] = "Lao People's Democratic Republic",
["460"] = "China (People's Republic of)",
["461"] = "China (People's Republic of)",
["466"] = "Taiwan",
["467"] = "Democratic People's Republic of Korea",
["470"] = "Bangladesh (People's Republic of)",
["472"] = "Maldives (Republic of)",
["502"] = "Malaysia",
["505"] = "Australia",
["510"] = "Indonesia (Republic of)",
["514"] = "Democratique Republic of Timor-Leste",
["515"] = "Philippines (Republic of the)",
["520"] = "Thailand",
["525"] = "Singapore (Republic of)",
["528"] = "Brunei Darussalam",
["530"] = "New Zealand",
["534"] = "Northern Mariana Islands (Commonwealth of the)",
["535"] = "Guam",
["536"] = "Nauru (Republic of)",
["537"] = "Papua New Guinea",
["539"] = "Tonga (Kingdom of)",
["540"] = "Solomon Islands",
["541"] = "Vanuatu (Republic of)",
["542"] = "Fiji (Republic of)",
["543"] = "Wallis and Futuna",
["544"] = "American Samoa",
["545"] = "Kiribati (Republic of)",
["546"] = "New Caledonia",
["547"] = "French Polynesia",
["548"] = "Cook Islands",
["549"] = "Samoa (Independent State of)",
["550"] = "Micronesia (Federated States of)",
["551"] = "Marshall Islands (Republic of the)",
["552"] = "Palau (Republic of)",
["602"] = "Egypt (Arab Republic of)",
["603"] = "Algeria (People's Democratic Republic of)",
["604"] = "Morocco (Kingdom of)",
["605"] = "Tunisia",
["606"] = "Libya",
["607"] = "Gambia (Republic of the)",
["608"] = "Senegal (Republic of)",
["609"] = "Mauritania (Islamic Republic of)",
["610"] = "Mali (Republic of)",
["611"] = "Guinea (Republic of)",
["612"] = "Cote d'Ivoire (Republic of)",
["613"] = "Burkina Faso",
["614"] = "Niger (Republic of the)",
["615"] = "Togolese Republic",
["616"] = "Benin (Republic of)",
["617"] = "Mauritius (Republic of)",
["618"] = "Liberia (Republic of)",
["619"] = "Sierra Leone",
["620"] = "Ghana",
["621"] = "Nigeria (Federal Republic of)",
["622"] = "Chad (Republic of)",
["623"] = "Central African Republic",
["624"] = "Cameroon (Republic of)",
["625"] = "Cape Verde (Republic of)",
["626"] = "Sao Tome and Principe (Democratic Republic of)",
["627"] = "Equatorial Guinea (Republic of)",
["628"] = "Gabonese Republic",
["629"] = "Congo (Republic of the)",
["630"] = "Democratic Republic of the Congo",
["631"] = "Angola (Republic of)",
["632"] = "Guinea-Bissau (Republic of)",
["633"] = "Seychelles (Republic of)",
["634"] = "Sudan (Republic of the)",
["635"] = "Rwandese Republic",
["636"] = "Ethiopia (Federal Democratic Republic of)",
["637"] = "Somali Democratic Republic",
["638"] = "Djibouti (Republic of)",
["639"] = "Kenya (Republic of)",
["640"] = "Tanzania (United Republic of)",
["641"] = "Uganda (Republic of)",
["642"] = "Burundi (Republic of)",
["643"] = "Mozambique (Republic of)",
["645"] = "Zambia (Republic of)",
["646"] = "Madagascar (Republic of)",
["647"] = "Reunion (French Department of)",
["648"] = "Zimbabwe (Republic of)",
["649"] = "Namibia (Republic of)",
["650"] = "Malawi",
["651"] = "Lesotho (Kingdom of)",
["652"] = "Botswana (Republic of)",
["653"] = "Swaziland (Kingdom of)",
["654"] = "Comoros (Union of the)",
["655"] = "South Africa (Republic of)",
["657"] = "Eritrea",
["702"] = "Belize",
["704"] = "Guatemala (Republic of)",
["706"] = "El Salvador (Republic of)",
["708"] = "Honduras (Republic of)",
["710"] = "Nicaragua",
["712"] = "Costa Rica",
["714"] = "Panama (Republic of)",
["716"] = "Peru",
["722"] = "Argentine Republic",
["724"] = "Brazil (Federative Republic of)",
["730"] = "Chile",
["732"] = "Colombia (Republic of)",
["734"] = "Venezuela (Bolivarian Republic of)",
["736"] = "Bolivia (Republic of)",
["738"] = "Guyana",
["740"] = "Ecuador",
["742"] = "French Guiana (French Department of)",
["744"] = "Paraguay (Republic of)",
["746"] = "Suriname (Republic of)",
["748"] = "Uruguay (Eastern Republic of)",
["412"] = "Afghanistan",
["276"] = "Albania (Republic of)",
["603"] = "Algeria (People's Democratic Republic of)",
["544"] = "American Samoa",
["213"] = "Andorra (Principality of)",
["631"] = "Angola (Republic of)",
["365"] = "Anguilla",
["344"] = "Antigua and Barbuda",
["722"] = "Argentine Republic",
["283"] = "Armenia (Republic of)",
["363"] = "Aruba",
["505"] = "Australia",
["232"] = "Austria",
["400"] = "Azerbaijani Republic",
["364"] = "Bahamas (Commonwealth of the)",
["426"] = "Bahrain (Kingdom of)",
["470"] = "Bangladesh (People's Republic of)",
["342"] = "Barbados",
["257"] = "Belarus (Republic of)",
["206"] = "Belgium",
["702"] = "Belize",
["616"] = "Benin (Republic of)",
["350"] = "Bermuda",
["402"] = "Bhutan (Kingdom of)",
["736"] = "Bolivia (Republic of)",
["218"] = "Bosnia and Herzegovina",
["652"] = "Botswana (Republic of)",
["724"] = "Brazil (Federative Republic of)",
["348"] = "British Virgin Islands",
["528"] = "Brunei Darussalam",
["284"] = "Bulgaria (Republic of)",
["613"] = "Burkina Faso",
["642"] = "Burundi (Republic of)",
["456"] = "Cambodia (Kingdom of)",
["624"] = "Cameroon (Republic of)",
["302"] = "Canada",
["625"] = "Cape Verde (Republic of)",
["346"] = "Cayman Islands",
["623"] = "Central African Republic",
["622"] = "Chad (Republic of)",
["730"] = "Chile",
["461"] = "China (People's Republic of)",
["460"] = "China (People's Republic of)",
["732"] = "Colombia (Republic of)",
["654"] = "Comoros (Union of the)",
["629"] = "Congo (Republic of the)",
["548"] = "Cook Islands",
["712"] = "Costa Rica",
["612"] = "Cote d'Ivoire (Republic of)",
["219"] = "Croatia (Republic of)",
["368"] = "Cuba",
["280"] = "Cyprus (Republic of)",
["230"] = "Czech Republic",
["467"] = "Democratic People's Republic of Korea",
["630"] = "Democratic Republic of the Congo",
["514"] = "Democratique Republic of Timor-Leste",
["238"] = "Denmark",
["638"] = "Djibouti (Republic of)",
["366"] = "Dominica (Commonwealth of)",
["370"] = "Dominican Republic",
["740"] = "Ecuador",
["602"] = "Egypt (Arab Republic of)",
["706"] = "El Salvador (Republic of)",
["627"] = "Equatorial Guinea (Republic of)",
["657"] = "Eritrea",
["248"] = "Estonia (Republic of)",
["636"] = "Ethiopia (Federal Democratic Republic of)",
["288"] = "Faroe Islands",
["542"] = "Fiji (Republic of)",
["244"] = "Finland",
["208"] = "France",
["742"] = "French Guiana (French Department of)",
["547"] = "French Polynesia",
["628"] = "Gabonese Republic",
["607"] = "Gambia (Republic of the)",
["282"] = "Georgia",
["262"] = "Germany (Federal Republic of)",
["620"] = "Ghana",
["266"] = "Gibraltar",
["202"] = "Greece",
["290"] = "Greenland (Denmark)",
["352"] = "Grenada",
["340"] = "Guadeloupe (French Department of)",
["535"] = "Guam",
["704"] = "Guatemala (Republic of)",
["611"] = "Guinea (Republic of)",
["632"] = "Guinea-Bissau (Republic of)",
["738"] = "Guyana",
["372"] = "Haiti (Republic of)",
["708"] = "Honduras (Republic of)",
["454"] = "Hongkong China",
["216"] = "Hungary (Republic of)",
["274"] = "Iceland",
["404"] = "India (Republic of)",
["510"] = "Indonesia (Republic of)",
["901"] = "International Mobile shared code c",
["432"] = "Iran (Islamic Republic of)",
["418"] = "Iraq (Republic of)",
["272"] = "Ireland",
["425"] = "Israel (State of)",
["222"] = "Italy",
["338"] = "Jamaica",
["441"] = "Japan",
["440"] = "Japan",
["416"] = "Jordan (Hashemite Kingdom of)",
["401"] = "Kazakhstan (Republic of)",
["639"] = "Kenya (Republic of)",
["545"] = "Kiribati (Republic of)",
["450"] = "Korea (Republic of)",
["419"] = "Kuwait (State of)",
["437"] = "Kyrgyz Republic",
["457"] = "Lao People's Democratic Republic",
["247"] = "Latvia (Republic of)",
["415"] = "Lebanon",
["651"] = "Lesotho (Kingdom of)",
["618"] = "Liberia (Republic of)",
["606"] = "Libya",
["295"] = "Liechtenstein (Principality of)",
["246"] = "Lithuania (Republic of)",
["270"] = "Luxembourg",
["455"] = "Macao China",
["646"] = "Madagascar (Republic of)",
["650"] = "Malawi",
["502"] = "Malaysia",
["472"] = "Maldives (Republic of)",
["610"] = "Mali (Republic of)",
["278"] = "Malta",
["551"] = "Marshall Islands (Republic of the)",
["340"] = "Martinique (French Department of)",
["609"] = "Mauritania (Islamic Republic of)",
["617"] = "Mauritius (Republic of)",
["334"] = "Mexico",
["550"] = "Micronesia (Federated States of)",
["259"] = "Moldova (Republic of)",
["212"] = "Monaco (Principality of)",
["428"] = "Mongolia",
["354"] = "Montserrat",
["604"] = "Morocco (Kingdom of)",
["643"] = "Mozambique (Republic of)",
["414"] = "Myanmar (Union of)",
["649"] = "Namibia (Republic of)",
["536"] = "Nauru (Republic of)",
["429"] = "Nepal",
["204"] = "Netherlands (Kingdom of the)",
["362"] = "Netherlands Antilles",
["546"] = "New Caledonia",
["530"] = "New Zealand",
["710"] = "Nicaragua",
["614"] = "Niger (Republic of the)",
["621"] = "Nigeria (Federal Republic of)",
["534"] = "Northern Mariana Islands (Commonwealth of the)",
["242"] = "Norway",
["422"] = "Oman (Sultanate of)",
["410"] = "Pakistan (Islamic Republic of)",
["552"] = "Palau (Republic of)",
["714"] = "Panama (Republic of)",
["537"] = "Papua New Guinea",
["744"] = "Paraguay (Republic of)",
["716"] = "Peru",
["515"] = "Philippines (Republic of the)",
["260"] = "Poland (Republic of)",
["268"] = "Portugal",
["330"] = "Puerto Rico",
["427"] = "Qatar (State of)",
["8XX"] = "Reserved a 0XX Reserved a 1XX Reserved a",
["647"] = "Reunion (French Department of) 226 Romania",
["250"] = "Russian Federation",
["635"] = "Rwandese Republic",
["356"] = "Saint Kitts and Nevis",
["358"] = "SaintLucia",
["308"] = "Saint Pierre and Miquelon",
["360"] = "Saint Vincent and the Grenadines",
["549"] = "Samoa (Independent State of)",
["292"] = "San Marino (Republic of)",
["626"] = "Sao Tome and Principe (Democratic Republic of)",
["420"] = "Saudi Arabia (Kingdom of)",
["608"] = "Senegal (Republic of)",
["220"] = "Serbia and Montenegro",
["633"] = "Seychelles (Republic of)",
["619"] = "Sierra Leone",
["525"] = "Singapore (Republic of)",
["231"] = "Slovak Republic",
["293"] = "Slovenia (Republic of)",
["540"] = "Solomon Islands",
["637"] = "Somali Democratic Republic",
["655"] = "South Africa (Republic of)",
["214"] = "Spain",
["413"] = "Sri Lanka (Democratic Socialist Republic of)",
["634"] = "Sudan (Republic of the)",
["746"] = "Suriname (Republic of)",
["653"] = "Swaziland (Kingdom of)",
["240"] = "Sweden",
["228"] = "Switzerland (Confederation of)",
["417"] = "Syrian Arab Republic",
["466"] = "Taiwan",
["436"] = "Tajikistan (Republic of)",
["640"] = "Tanzania (United Republic of)",
["520"] = "Thailand",
["294"] = "The Former Yugoslav Republic of Macedonia",
["615"] = "Togolese Republic",
["539"] = "Tonga (Kingdom of)",
["374"] = "Trinidad and Tobago",
["605"] = "Tunisia",
["286"] = "Turkey",
["438"] = "Turkmenistan",
["376"] = "Turks and Caicos Islands",
["641"] = "Uganda (Republic of)",
["255"] = "Ukraine",
["424"] = "United Arab Emirates",
["430"] = "United Arab Emirates b",
["431"] = "United Arab Emirates b",
["235"] = "United Kingdom",
["234"] = "United Kingdom",
["310"] = "United States of America",
["316"] = "United States of America",
["311"] = "United States of America",
["312"] = "United States of America",
["313"] = "United States of America",
["314"] = "United States of America",
["315"] = "United States of America",
["332"] = "United States Virgin Islands",
["748"] = "Uruguay (Eastern Republic of)",
["434"] = "Uzbekistan (Republic of)",
["541"] = "Vanuatu (Republic of)",
["225"] = "Vatican City State",
["734"] = "Venezuela (Bolivarian Republic of)",
["452"] = "Viet Nam (Socialist Republic of)",
["543"] = "Wallis and Futuna",
["421"] = "Yemen (Republic of)",
["645"] = "Zambia (Republic of)",
["648"] = "Zimbabwe (Republic of)",
}

-- ################################################################################

local function dumpStatusDefs()
   for _, a in pairsByKeys(status_by_id) do
      print("[status_id: ".. a.status_id .."][prio: ".. a.prio .."][title: ".. a.i18n_title.."]\n")
      -- tprint(k)
   end
end

-- ################################################################################

-- Load definitions now
loadStatusDefs()

-- Print definitions: enable for debugging
-- dumpStatusDefs()

return flow_consts
