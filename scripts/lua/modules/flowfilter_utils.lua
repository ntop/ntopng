--
-- (C) 2020-26 - ntop.org
--
if (pragma_once_flowfilter_utils == true) then
    -- io.write(debug.traceback().."\n")
    -- avoid multiple inclusions
    return
end

pragma_once_flowfilter_utils = true

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_consts = require "alert_consts"
local host_pools = require "host_pools"
local consts = require "consts"
local tag_badge_utils = require "tag_badge_utils"
require "lua_utils_get"
local qoe_utils

if ntop.isEnterpriseL and ntop.isEnterpriseL() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
    qoe_utils = require "qoe_utils"
end

local MAX_NUM_ENTRIES = 300
local snmp_filter_options_cache

local flowfilter_utils = {}

-- Operator Separator in query strings
flowfilter_utils.SEPARATOR = consts.SEPARATOR

-- #####################################

-- Supported operators
-- (empty string if there is no direct match)
flowfilter_utils.flowfilter_operators_sql = {
    ["eq"] = "=",
    ["neq"] = "!=",
    ["lt"] = "<",
    ["gt"] = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
    ["in"] = "",
    ["nin"] = "",
    ["empty"] = "",
    ["nempty"] = ""
}

-- Operator to string (i18n)
flowfilter_utils.flowfilter_operators_label = {
    ["eq"] = "=",
    ["neq"] = "!=",
    ["lt"] = "<",
    ["gt"] = ">",
    ["gte"] = ">=",
    ["lte"] = "<=",
    ["in"] = i18n("has"),
    ["nin"] = i18n("does_not_have"),
    ["empty"] = i18n("is_empty"),
    ["nempty"] = i18n("is_not_empty")
}

-- #####################################

-- Supported input types
flowfilter_utils.input_types = {
    input = 'input',
    select = 'select',
    select_with_input = 'select-with-input'
}

-- #####################################

flowfilter_utils.defined_filters = {
    alert_id = {
        type = flowfilter_utils.input_types.select,
        value_type = 'alert_id',
        i18n_label = i18n('db_search.flowfilters.alert_id'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    alert_category = {
        type = flowfilter_utils.input_types.select,
        value_type = 'alert_category',
        i18n_label = i18n('db_search.flowfilters.alert_category'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    l7proto = {
        type = flowfilter_utils.input_types.select,
        value_type = 'l7_proto',
        i18n_label = i18n('db_search.flowfilters.l7_proto'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    l7proto_master = {
        type = flowfilter_utils.input_types.select,
        value_type = 'l7_proto',
        i18n_label = i18n('db_search.flowfilters.l7_proto'),
        operators = {'eq', 'neq'},
        hide = true,
        hourly_available = true
    },
    l7cat = {
        type = flowfilter_utils.input_types.select,
        value_type = 'l7_category',
        i18n_label = i18n('db_search.flowfilters.l7cat'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    flow_risk = {
        type = flowfilter_utils.input_types.select,
        value_type = 'flow_risk',
        i18n_label = i18n('db_search.flowfilters.flow_risk'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    tag = {
        type = flowfilter_utils.input_types.select,
        value_type = 'tag_id',
        i18n_label = i18n('db_search.flowfilters.tag'),
        operators = {'in', 'nin'},
        hourly_available = true
    },
    cli_tag = {
        type = flowfilter_utils.input_types.select,
        value_type = 'tag_id',
        i18n_label = i18n('db_search.flowfilters.cli_tag'),
        operators = {'in', 'nin'},
        hourly_available = true
    },
    srv_tag = {
        type = flowfilter_utils.input_types.select,
        value_type = 'tag_id',
        i18n_label = i18n('db_search.flowfilters.srv_tag'),
        operators = {'in', 'nin'},
        hourly_available = true
    },
    l4proto = {
        type = flowfilter_utils.input_types.select,
        value_type = 'l4_proto',
        i18n_label = i18n('db_search.flowfilters.l4proto'),
        operators = {'eq', 'neq'},
        bpf_key = 'ip proto',
        hourly_available = true
    },
    ip_version = {
        type = flowfilter_utils.input_types.select,
        value_type = 'ip_version',
        i18n_label = i18n('db_search.flowfilters.ip_version'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    ip = {
        value_type = 'ip,cidr', -- Set to 'ip' to accept IP only
        i18n_label = i18n('db_search.flowfilters.ip'),
        operators = {'eq', 'neq'},
        bpf_key = 'ip host',
        hourly_available = true
    },
    cli_ip = {
        value_type = 'ip,cidr', -- Set to 'ip' to accept IP only
        i18n_label = i18n('db_search.flowfilters.cli_ip'),
        operators = {'eq', 'neq'},
        bpf_key = 'ip host',
        hourly_available = true
    },
    srv_ip = {
        value_type = 'ip,cidr', -- Set to 'ip' to accept IP only
        i18n_label = i18n('db_search.flowfilters.srv_ip'),
        operators = {'eq', 'neq'},
        bpf_key = 'ip host',
        hourly_available = true
    },
    network_cidr = {
        value_type = 'cidr',
        i18n_label = i18n('db_search.flowfilters.network_cidr'),
        operators = {'eq', 'neq'},
        bpf_key = 'net',
        hourly_available = true
    },
    cli_network_cidr = {
        value_type = 'cidr',
        i18n_label = i18n('db_search.flowfilters.cli_network_cidr'),
        operators = {'eq', 'neq'},
        bpf_key = 'net',
        hourly_available = true
    },
    srv_network_cidr = {
        value_type = 'cidr',
        i18n_label = i18n('db_search.flowfilters.srv_network_cidr'),
        operators = {'eq', 'neq'},
        bpf_key = 'net',
        hourly_available = true
    },
    traffic_direction = {
        type = flowfilter_utils.input_types.select,
        value_type = 'traffic_direction',
        i18n_label = i18n('db_search.flowfilters.traffic_direction'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    name = {
        value_type = 'hostname',
        i18n_label = i18n('db_search.flowfilters.name'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = true
    },
    cli_name = {
        value_type = 'hostname',
        i18n_label = i18n('db_search.flowfilters.cli_name'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = true
    },
    srv_name = {
        value_type = 'hostname',
        i18n_label = i18n('db_search.flowfilters.srv_name'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = true
    },
    network_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.network_name'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    src2dst_dscp = {
        type = flowfilter_utils.input_types.select,
        value_type = 'dscp_type',
        i18n_label = i18n('db_search.flowfilters.src2dst_dscp'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    dst2src_dscp = {
        type = flowfilter_utils.input_types.select,
        value_type = 'dscp_type',
        i18n_label = i18n('db_search.flowfilters.dst2src_dscp'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    duration = {
        value_type = 'number',
        i18n_label = i18n('db_search.duration'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    cli_port = {
        value_type = 'port',
        i18n_label = i18n('db_search.flowfilters.cli_port'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        bpf_key = 'port',
        hourly_available = false
    },
    srv_port = {
        value_type = 'port',
        i18n_label = i18n('db_search.flowfilters.srv_port'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        bpf_key = 'port',
        hourly_available = true
    },
    country = {
        type = flowfilter_utils.input_types.select,
        value_type = 'country',
        i18n_label = i18n('db_search.flowfilters.country'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    cli_country = {
        type = flowfilter_utils.input_types.select,
        value_type = 'country',
        i18n_label = i18n('db_search.flowfilters.cli_country'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    srv_country = {
        type = flowfilter_utils.input_types.select,
        value_type = 'country',
        i18n_label = i18n('db_search.flowfilters.srv_country'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    asn = {
        value_type = 'asn',
        i18n_label = i18n('db_search.flowfilters.asn'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    cli_asn = {
        value_type = 'asn',
        i18n_label = i18n('db_search.flowfilters.cli_asn'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    srv_asn = {
        value_type = 'asn',
        i18n_label = i18n('db_search.flowfilters.srv_asn'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    src_peer_asn = {
        value_type = 'asn',
        i18n_label = i18n('db_search.flowfilters.src_peer_asn'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    dst_peer_asn = {
        value_type = 'asn',
        i18n_label = i18n('db_search.flowfilters.dst_peer_asn'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    cli_nw_latency = {
        value_type = 'nw_latency_type',
        i18n_label = i18n('db_search.flowfilters.cli_nw_latency'),
        operators = {'eq', 'lt', 'gt', 'lte', 'gte'},
        hourly_available = false
    },
    srv_nw_latency = {
        value_type = 'nw_latency_type',
        i18n_label = i18n('db_search.flowfilters.srv_nw_latency'),
        operators = {'eq', 'lt', 'gt', 'lte', 'gte'},
        hourly_available = false
    },
    observation_point_id = {
        type = flowfilter_utils.input_types.select,
        value_type = 'observation_point_id',
        i18n_label = i18n('db_search.flowfilters.observation_point_id'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    probe_ip = {
        type = flowfilter_utils.input_types.select_with_input,
        value_type = 'probe_ip',
        i18n_label = i18n('db_search.flowfilters.probe_ip'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    site = { -- Exporter site
        type = flowfilter_utils.input_types.select,
        value_type = 'site',
        i18n_label = i18n('db_search.flowfilters.site'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    network_site = { -- Network site
        type = flowfilter_utils.input_types.select,
        value_type = 'site',
        i18n_label = i18n('db_search.flowfilters.network_site'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    cli_site = { -- Client site
        type = flowfilter_utils.input_types.select,
        value_type = 'site',
        i18n_label = i18n('db_search.flowfilters.cli_site'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    srv_site = { -- Server site
        type = flowfilter_utils.input_types.select,
        value_type = 'site',
        i18n_label = i18n('db_search.flowfilters.srv_site'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    vlan_id = {
        value_type = 'vlan_id',
        i18n_label = i18n('db_search.flowfilters.vlan_id'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    snmp_interface = {
        type = flowfilter_utils.input_types.select,
        value_type = 'snmp_interface',
        i18n_label = i18n('db_search.flowfilters.snmp_interface'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    input_snmp = {
        type = flowfilter_utils.input_types.select,
        value_type = 'snmp_interface',
        i18n_label = i18n('db_search.flowfilters.input_snmp'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    output_snmp = {
        type = flowfilter_utils.input_types.select,
        value_type = 'snmp_interface',
        i18n_label = i18n('db_search.flowfilters.output_snmp'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    iface_role = {
        type = flowfilter_utils.input_types.select,
        value_type = 'iface_role',
        i18n_label = i18n('as_stats.interface_role'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    src2dst_tcp_flags = {
        value_type = 'flags',
        i18n_label = i18n('db_search.src2dst_tcp_flags'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    dst2src_tcp_flags = {
        value_type = 'flags',
        i18n_label = i18n('db_search.dst2src_tcp_flags'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    alert_status = {
        type = flowfilter_utils.input_types.select,
        value_type = 'alert_status',
        i18n_label = i18n('db_search.flowfilters.alert_status'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    require_attention = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.require_attention'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    severity = {
        type = flowfilter_utils.input_types.select,
        value_type = 'severity',
        i18n_label = i18n('db_search.flowfilters.severity'),
        operators = {'eq', 'lte', 'gte', 'neq'},
        hourly_available = false
    },
    score = {
        value_type = 'score',
        i18n_label = i18n('db_search.flowfilters.score'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    qoe_score = {
        type = flowfilter_utils.input_types.select,
        value_type = 'qoe_score',
        i18n_label = i18n('db_search.flowfilters.qoe'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = false
    },
    mac = {
        value_type = 'mac',
        i18n_label = i18n('db_search.flowfilters.mac'),
        operators = {'eq', 'neq'},
        bpf_key = 'ether host',
        hourly_available = true
    },
    cli_mac = {
        value_type = 'mac',
        i18n_label = i18n('db_search.flowfilters.cli_mac'),
        operators = {'eq', 'neq'},
        bpf_key = 'ether host',
        hourly_available = true
    },
    srv_mac = {
        value_type = 'mac',
        i18n_label = i18n('db_search.flowfilters.srv_mac'),
        operators = {'eq', 'neq'},
        bpf_key = 'ether host',
        hourly_available = true
    },
    network = {
        type = flowfilter_utils.input_types.select,
        value_type = 'network_id',
        i18n_label = i18n('db_search.flowfilters.network'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    cli_network = {
        type = flowfilter_utils.input_types.select,
        value_type = 'network_id',
        i18n_label = i18n('db_search.flowfilters.cli_network'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    srv_network = {
        type = flowfilter_utils.input_types.select,
        value_type = 'network_id',
        i18n_label = i18n('db_search.flowfilters.srv_network'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    info = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.info'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    bytes = {
        value_type = 'bytes',
        i18n_label = i18n('db_search.flowfilters.bytes'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    cli2srv_bytes = {
        type = flowfilter_utils.input_types.input,
        value_type = 'number',
        i18n_label = i18n('traffic_labels.cli2srv_bytes'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    srv2cli_bytes = {
        type = flowfilter_utils.input_types.input,
        value_type = 'number',
        i18n_label = i18n('traffic_labels.srv2cli_bytes'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    packets = {
        value_type = 'packets',
        i18n_label = i18n('db_search.flowfilters.packets'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    cli2srv_packets = {
        value_type = 'packets',
        i18n_label = i18n('traffic_labels.cli2srv_packets'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    srv2cli_packets = {
        value_type = 'packets',
        i18n_label = i18n('traffic_labels.srv2cli_packets'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    number = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.number'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = false
    },
    out_of_order = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.out_of_order'),
        operators = {'eq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = false
    },
    lost = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.lost'),
        operators = {'eq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = false
    },
    retransmissions = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.retransmissions'),
        operators = {'eq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = false
    },
    flows_number = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.flows_number'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    host_pool = {
        type = flowfilter_utils.input_types.select,
        value_type = 'host_pool',
        i18n_label = i18n('db_search.flowfilters.host_pool_id'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    cli_host_pool_id = {
        type = flowfilter_utils.input_types.select,
        value_type = 'host_pool_id',
        i18n_label = i18n('db_search.flowfilters.cli_host_pool_id'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    srv_host_pool_id = {
        type = flowfilter_utils.input_types.select,
        value_type = 'host_pool_id',
        i18n_label = i18n('db_search.flowfilters.srv_host_pool_id'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    subtype = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.subtype'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    role = {
        type = flowfilter_utils.input_types.select,
        value_type = 'role',
        i18n_label = i18n('db_search.flowfilters.role'),
        operators = {'eq'},
        hourly_available = false
    },
    role_cli_srv = {
        type = flowfilter_utils.input_types.select,
        value_type = 'role_cli_srv',
        i18n_label = i18n('db_search.flowfilters.role_cli_srv'),
        operators = {'eq'},
        hourly_available = false
    },
    l7_error_id = {
        value_type = 'l7_error_id',
        i18n_label = i18n('db_search.flowfilters.error_code'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    confidence = {
        type = flowfilter_utils.input_types.select,
        value_type = 'confidence',
        i18n_label = i18n('db_search.flowfilters.confidence'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    community_id = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.community_id'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    cli_fingerprint = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.cli_fingerprint'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    tcp_fingerprint = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.tcp_fingerprint'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    ndpi_fingerprint = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.ndpi_fingerprint'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    -- ja4_client = {
    --    value_type = 'text',
    --    i18n_label = i18n('ja4_client_hash'),
    --    operators = { 'eq', 'neq' }
    -- },
    http_method = {
        type = flowfilter_utils.input_types.select,
        value_type = 'http_method',
        i18n_label = i18n('db_search.flowfilters.http_method'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    http_return = {
        type = flowfilter_utils.input_types.select,
        value_type = 'http_return',
        i18n_label = i18n('db_search.flowfilters.http_return_code'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    http_url = {
        value_type = 'http_url',
        i18n_label = i18n('db_search.flowfilters.http_url'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    issuer_dn = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.issuer_dn'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    user_agent = {
        value_type = 'user_agent',
        i18n_label = i18n('db_search.flowfilters.user_agent'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    last_server = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.last_server'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    netbios_name = {
        value_type = 'netbios_name',
        i18n_label = i18n('db_search.flowfilters.netbios_name'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    dns_query = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.dns_query'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    dns_answer = {
        value_type = 'dns_answer',
        i18n_label = i18n('db_search.flowfilters.dns_answer'),
        operators = {'eq', 'neq', 'in', 'nin'},
        hourly_available = false
    },
    mdns_answer = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.mdns_answer'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    mdns_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.mdns_name'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    mdns_name_txt = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.mdns_name_txt'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    mdns_ssid = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.mdns_ssid'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    domain_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.domain_name'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    alert_domain = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.dga_domain_name'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'},
        hourly_available = false
    },
    cli_location = {
        type = flowfilter_utils.input_types.select,
        value_type = 'location',
        i18n_label = i18n('db_search.flowfilters.cli_location'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    srv_location = {
        type = flowfilter_utils.input_types.select,
        value_type = 'location',
        i18n_label = i18n('db_search.flowfilters.srv_location'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    host_location = {
        type = flowfilter_utils.input_types.select,
        value_type = 'location',
        i18n_label = i18n('db_search.flowfilters.host_location'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    cli_proc_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.cli_proc_name'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    srv_proc_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.srv_proc_name'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    cli_user_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.cli_user_name'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    srv_user_name = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.srv_user_name'),
        operators = {'eq', 'neq', 'empty', 'nempty'},
        hourly_available = false
    },
    major_connection_state = {
        type = flowfilter_utils.input_types.select,
        value_type = 'major_connection_state',
        i18n_label = i18n("db_search.flowfilters.major_connection_state"),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    minor_connection_state = {
        type = flowfilter_utils.input_types.select,
        value_type = 'minor_connection_state',
        i18n_label = i18n("db_search.flowfilters.minor_connection_state"),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    post_nat_ipv4_src_addr = {
        value_type = 'ip',
        i18n_label = i18n("db_search.flowfilters.post_nat_ipv4_src_addr"),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    post_nat_ipv4_dst_addr = {
        value_type = 'ip',
        i18n_label = i18n("db_search.flowfilters.post_nat_ipv4_dst_addr"),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    post_nat_src_port = {
        value_type = 'port',
        i18n_label = i18n("db_search.flowfilters.post_nat_src_port"),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    post_nat_dst_port = {
        value_type = 'port',
        i18n_label = i18n("db_search.flowfilters.post_nat_dst_port"),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    description = {
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.alert_description'),
        operators = {'in', 'empty', 'nempty'},
        hourly_available = false
    },
    mitre_tactic = {
        type = flowfilter_utils.input_types.select,
        value_type = 'mitre_tactic',
        i18n_label = i18n('db_search.flowfilters.mitre_tactic'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    mitre_technique = {
        type = flowfilter_utils.input_types.select,
        value_type = 'mitre_technique',
        i18n_label = i18n('db_search.flowfilters.mitre_technique'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    mitre_subtechnique = {
        type = flowfilter_utils.input_types.select,
        value_type = 'mitre_subtechnique',
        i18n_label = i18n('db_search.flowfilters.mitre_subtechnique'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    mitre_id = {
        type = flowfilter_utils.input_types.select,
        value_type = 'mitre_id',
        i18n_label = i18n('db_search.flowfilters.mitre_id'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    wlan_ssid = {
        -- type = flowfilter_utils.input_types.select,
        -- value_type = 'wlan_ssid',
        value_type = 'text',
        i18n_label = i18n('db_search.flowfilters.wlan_ssid'),
        operators = {'eq', 'neq', 'in', 'nin', 'empty', 'nempty'}
    },
    apn_mac = {
        value_type = 'mac',
        i18n_label = i18n('db_search.flowfilters.apn_mac'),
        operators = {'eq', 'neq'}
    },
    is_srv_blacklisted = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.is_srv_blacklisted'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    is_cli_blacklisted = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.is_cli_blacklisted'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    is_srv_victim = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.is_srv_victim'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    is_cli_victim = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.is_cli_victim'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    is_srv_attacker = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.is_srv_attacker'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    is_cli_attacker = {
        value_type = 'boolean',
        i18n_label = i18n('db_search.flowfilters.is_cli_attacker'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    verdict = {
        type = flowfilter_utils.input_types.select,
        value_type = 'verdict',
        i18n_label = i18n('details.flow_verdict'),
        operators = {'eq', 'neq'},
        hourly_available = false
    },
    ntopng_interface = {
        type = flowfilter_utils.input_types.select,
        value_type = 'interface_id',
        i18n_label = i18n('db_search.flowfilters.ntopng_interface'),
        operators = {'eq', 'neq'},
        hourly_available = true
    },
    first_seen = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.first_seen'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    last_seen = {
        value_type = 'number',
        i18n_label = i18n('db_search.flowfilters.last_seen'),
        operators = {'eq', 'neq', 'lt', 'gt', 'gte', 'lte'},
        hourly_available = true
    },
    first_flow_dump = {
        type = flowfilter_utils.input_types.select,
        value_type = 'first_flow_dump',
        i18n_label = i18n('db_search.flowfilters.first_flow_dump'),
        operators = {'eq', 'neq'},
        hourly_available = false
    }
}
-- #####################################

flowfilter_utils.traffic_direction = {{
    label = i18n("flows_page.remote_only"),
    id = 0
}, {
    label = i18n("flows_page.local_only"),
    id = 1
}, {
    label = i18n("flows_page.local_srv_remote_cli"),
    id = 2
}, {
    label = i18n("flows_page.local_cli_remote_srv"),
    id = 3
}}

-- #####################################

flowfilter_utils.confidence = {{
    label = i18n("confidence_unknown"),
    id = -1
}, {
    label = i18n("confidence_guessed"),
    id = 0
}, {
    label = i18n("confidence_dpi"),
    id = 1
}}

-- #####################################

flowfilter_utils.http_return = {{
    label = i18n("http_info.return_codes.200"),
    id = 200
}, {
    label = i18n("http_info.return_codes.400"),
    id = 400
}, {
    label = i18n("http_info.return_codes.401"),
    id = 401
}, {
    label = i18n("http_info.return_codes.403"),
    id = 403
}, {
    label = i18n("http_info.return_codes.404"),
    id = 404
}, {
    label = i18n("http_info.return_codes.405"),
    id = 405
}, {
    label = i18n("http_info.return_codes.406"),
    id = 406
}, {
    label = i18n("http_info.return_codes.408"),
    id = 408
}, {
    label = i18n("http_info.return_codes.409"),
    id = 409
}, {
    label = i18n("http_info.return_codes.410"),
    id = 410
}, {
    label = i18n("http_info.return_codes.412"),
    id = 412
}, {
    label = i18n("http_info.return_codes.415"),
    id = 415
}, {
    label = i18n("http_info.return_codes.423"),
    id = 423
}, {
    label = i18n("http_info.return_codes.428"),
    id = 428
}, {
    label = i18n("http_info.return_codes.429"),
    id = 429
}, {
    label = i18n("http_info.return_codes.500"),
    id = 500
}, {
    label = i18n("http_info.return_codes.501"),
    id = 501
}, {
    label = i18n("http_info.return_codes.503"),
    id = 503
}}

-- #####################################

flowfilter_utils.http_method = {{
    label = i18n("http_info.methods.get"),
    id = 'GET'
}, {
    label = i18n("http_info.methods.head"),
    id = 'HEAD'
}, {
    label = i18n("http_info.methods.post"),
    id = 'POST'
}, {
    label = i18n("http_info.methods.put"),
    id = 'PUT'
}, {
    label = i18n("http_info.methods.delete"),
    id = 'DELETE'
}, {
    label = i18n("http_info.methods.connect"),
    id = 'CONNECT'
}, {
    label = i18n("http_info.methods.options"),
    id = 'OPTIONS'
}, {
    label = i18n("http_info.methods.trace"),
    id = 'TRACE'
}, {
    label = i18n("http_info.methods.patch"),
    id = 'PATCH'
}}

-- #####################################

flowfilter_utils.location = {{
    label = i18n("details.label_remote"),
    id = 0
}, {
    label = i18n("details.label_local_host"),
    id = 1
}, {
    label = i18n("multicast"),
    id = 2
}}

-- #####################################

function flowfilter_utils.build_request_filter(key, op, value)
    return key .. '=' .. value .. flowfilter_utils.SEPARATOR .. op
end

-- #####################################

function flowfilter_utils.get_flowfilter_filters_from_request()
    local filters = {}
    for key, value in pairs(flowfilter_utils.defined_filters) do
        if _GET[key] ~= nil then
            filters[key] = _GET[key]
        end
    end

    if _GET["host"] then -- from the host page
        filters["ip"] = _GET["host"] -- convert to flowfilter key
    end

    for key, value in pairs(_GET or {}) do
        if key:starts('custom_fields') then
            filters[key] = value
        end
    end

    if not isEmptyString(filters['l7proto']) then
        local l7proto = ""
        -- Splitting per multiple l7protos
        for _, v in pairs(split(filters['l7proto'], ",")) do
            local l7string = ""
            -- Splitting per ; (e.g. 217.16;eq)
            local tmp_proto = split(v, ";")

            if tmp_proto[1] then
                -- Splitting per . , to get both master proto and app proto
                local app_protos = split(tmp_proto[1], "%%.")

                if not tonumber(app_protos[1]) then
                    app_protos[1] = interface.getnDPIProtoId(app_protos[1])
                end

                l7string = app_protos[1]

                if app_protos[2] then
                    if not tonumber(app_protos[2]) then
                        app_protos[2] = interface.getnDPIProtoId(app_protos[2])
                    end

                    l7string = l7string .. '.' .. app_protos[2]
                end
            end

            l7proto = l7proto .. l7string .. ";" .. tmp_proto[2] .. ","
        end

        filters['l7proto'] = l7proto:sub(1, -2)
    end

    return filters
end

-- ##############################################

-- @brief Evaluate operator
function flowfilter_utils.eval_op(v1, op, v2)
    local default_verdict = true

    -- Convert boolean for compatibility
    if type(v1) == 'boolean' then
        if v1 then
            v1 = 1
        else
            v1 = 0
        end
    end

    -- Convert numbers
    if type(v1) == 'number' and type(v2) ~= 'number' then
        v2 = tonumber(v2)
    end
    if type(v2) == 'number' and type(v1) ~= 'number' then
        v1 = tonumber(v1)
    end

    if not v1 or not v2 then
        return default_verdict
    end

    if op == 'eq' then
        return v1 == v2
    elseif op == 'neq' then
        return v1 ~= v2
    elseif op == 'lt' then
        return v1 < v2
    elseif op == 'gt' then
        return v1 > v2
    elseif op == 'gte' then
        return v1 >= v2
    elseif op == 'lte' then
        return v1 <= v2
    elseif op == 'in' then
        v_and = v1 & v2
        return v1 == v_and
    elseif op == 'nin' then
        v_and = v1 & v2
        return v1 ~= v_and
    end

    return default_verdict
end

-- #####################################

flowfilter_utils.formatters = {
    l4proto = function(proto)
        return l4_proto_to_string(proto)
    end,
    l4_proto = function(proto)
        return l4_proto_to_string(proto)
    end,
    l7_proto = function(proto)
        return interface.getnDPIProtoName(tonumber(proto))
    end,
    l7proto = function(proto)
        return interface.getnDPIProtoName(tonumber(proto))
    end,
    l7cat = function(cat)
        return getCategoryLabel(interface.getnDPICategoryName(tonumber(cat)), tonumber(cat))
    end,
    severity = function(severity)
        return (i18n(alert_consts.alertSeverityById(tonumber(severity)).i18n_title))
    end,
    alert_status = function(status)
        return (i18n(alert_consts.alertSeverityById(tonumber(status)).i18n_title))
    end,
    alert_id = function(status)
        local alert_entities = require "alert_entities"
        return alert_consts.alertTypeLabel(status, true, alert_entities.flow.entity_id)
    end,
    alert_category = function(category_id)
        local alert_category_utils = require "alert_category_utils"
        return alert_category_utils.getCategoryById(category_id)
    end,
    role = function(role)
        return (i18n(role))
    end,
    role_cli_srv = function(role)
        return (i18n(role))
    end,
    flow_risk = function(risk)
        local flow_risk_list = ntop.getRiskList() or {}
        flow_risk_list[1] = i18n("flow_risk.ndpi_no_risk")
        return flow_risk_list[tonumber(risk) + 1] or risk
    end,
    tag = function(id)
        for _, lbl in ipairs(tag_badge_utils.getTags()) do
            if tostring(lbl.id) == tostring(id) then
                return lbl.name
            end
        end
        return id
    end,
    cli_tag = function(id)
        for _, lbl in ipairs(tag_badge_utils.getTags()) do
            if tostring(lbl.id) == tostring(id) then
                return lbl.name
            end
        end
        return id
    end,
    srv_tag = function(id)
        for _, lbl in ipairs(tag_badge_utils.getTags()) do
            if tostring(lbl.id) == tostring(id) then
                return lbl.name
            end
        end
        return id
    end
}

-- ######################################

function flowfilter_utils.get_flowfilter_info(id, entity, hide_exporters_name, restrict_filters, ifid, is_aggregated)
    local alert_utils = require "alert_utils"
    local filter_def = flowfilter_utils.defined_filters[id]
    local changed_ifid = false
    local current_ifid = interface.getId()
    if filter_def == nil then
        -- traceError(TRACE_WARNING, TRACE_CONSOLE, "Flowfilter " .. id .. " not found")
        return nil
    end

    if not ifid then
        ifid = current_ifid
    else
        if tonumber(current_ifid) ~= tonumber(ifid) then
            changed_ifid = true
            interface.select(ifid)
        end
    end

    if is_aggregated and filter_def.hourly_available and (is_aggregated ~= filter_def.hourly_available) or is_aggregated and
        not filter_def.hourly_available then
        return nil
    end

    local filter = {
        id = id,
        label = filter_def.i18n_label,
        value_type = filter_def.value_type,
        value_label = filter_def.value_i18n_label or filter_def.i18n_label,
        operators = {},
        type = filter_def.type
    }

    for _, op in ipairs(filter_def.operators) do
        filter.operators[#filter.operators + 1] = {
            id = op,
            label = flowfilter_utils.flowfilter_operators_label[op]
        }
    end

    -- select (array of values)
    if (filter_def.value_type == "alert_id" or filter_def.value_type == "alert_type" --[[ alert_id should be used --]] ) and entity ~=
        nil then
        filter.value_type = 'array'
        filter.options = {}
        local alert_types = alert_consts.getAlertTypesInfo(entity.entity_id)
        for id, info in pairsByField(alert_types, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = id,
                label = info.label
            }
        end
    elseif filter_def.value_type == "interface_id" then
        filter.value_type = 'array'
        filter.options = {}
        local iface_id_key = "ntopng.prefs.iface_id"
        local keys = ntop.getHashKeysCache(iface_id_key) or {}
        for name, _ in pairs(keys) do
            if not isnumber(name) then
                local id = ntop.getHashCache(iface_id_key, name)
                filter.options[#filter.options + 1] = {
                    value = id,
                    label = name
                }
            end
        end
    elseif filter_def.value_type == "first_flow_dump" then
        filter.value_type = 'array'
        filter.options = {
            {
                value = 1,
                label = i18n('db_search.flowfilters.first_flow_dump_only')
            },
            {
                value = 0,
                label = i18n('db_search.flowfilters.first_flow_dump_excluded')
            }
        }
    elseif filter_def.value_type == "qoe_score" then
        if not qoe_utils then
            -- Exclude the filter if it's not L, this info is found only in the l version
            filter = nil
            return nil
        end
        filter.value_type = 'array'
        filter.options = {}
        for _, info in pairsByKeys(qoe_utils.getPossibleQoE(), asc) do
            filter.options[#filter.options + 1] = {
                value = info.value,
                label = i18n(info.i18n_label)
            }
        end
    elseif filter_def.value_type == "mitre_id" then
        filter.value_type = 'array'
        filter.options = {}
        for name, info in pairsByField(alert_consts.getAllAlertMitreInfoIDs(), 'mitre_id', asc) do
            filter.options[#filter.options + 1] = {
                value = info.mitre_id,
                label = info.mitre_id
            }
        end
        --[[ Temporary commented out to reduce overhead (using open 'text' as value_type)
	 elseif filter_def.value_type == "wlan_ssid" then
	 local flows_stats = interface.getActiveFlowsStats()
	 filter.value_type = 'array'
	 filter.options = {}
	 local tmp_list = {}

	 if table.len(flows_stats["wlan_ssid"]) > 0 then
	 local tmp_list = {}
	 for key, value in pairs(flows_stats["wlan_ssid"] or {}, asc) do
	 tmp_list[key] = {
	 key = "wlan_ssid",
	 value = key,
	 label = key
	 }
	 end
	 for key, _ in pairsByKeys(tmp_list, asc) do
	 filter.options[#filter.options + 1] = {
	 value = key,
	 label = key,
	 }
	 end
	 end
      --]]
    elseif filter_def.value_type == "mitre_tactic" then
        filter.value_type = 'array'
        filter.options = {}
        local mitre_utils = require "mitre_utils"
        for name, info in pairsByField(mitre_utils.tactic, 'i18n_label', asc) do
            filter.options[#filter.options + 1] = {
                value = info.id,
                label = i18n(info.i18n_label)
            }
        end
    elseif filter_def.value_type == "mitre_technique" then
        filter.value_type = 'array'
        filter.options = {}
        local mitre_utils = require "mitre_utils"
        for name, info in pairsByField(mitre_utils.technique, 'i18n_label', asc) do
            filter.options[#filter.options + 1] = {
                value = info.id,
                label = i18n(info.i18n_label)
            }
        end
    elseif filter_def.value_type == "mitre_subtechnique" then
        filter.value_type = 'array'
        filter.options = {}
        local mitre_utils = require "mitre_utils"
        for name, info in pairsByField(mitre_utils.sub_technique, 'i18n_label', asc) do
            filter.options[#filter.options + 1] = {
                value = info.id,
                label = i18n(info.i18n_label)
            }
        end
    elseif filter_def.value_type == "alert_category" then
        filter.value_type = 'array'
        filter.options = {}
        local alert_categories = require "alert_categories"
        for name, info in pairsByField(alert_categories, 'i18n_title', asc) do
            filter.options[#filter.options + 1] = {
                value = info.id,
                label = i18n(info.i18n_title)
            }
        end
    elseif filter_def.value_type == "dscp_type" then
        local dscp_consts = require "dscp_consts"
        filter.value_type = 'array'
        filter.options = {}
        local dscp_types = dscp_consts.dscp_class_list()
        for id, info in pairsByField(dscp_types, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = id,
                label = info.label
            }
        end
    elseif filter_def.value_type == "verdict" then
        if not (ntop.isnEdge and ntop.isnEdge()) then
            return nil
        end
        -- nEdge verdict
        filter.value_type = 'array'
        filter.options = {}
        -- Using 1 and 2 because some issue can happen with value = 0; it's going to be
        -- transformed into 0 and 1 respectively in pro/scripts/lua/modules/flow_db/clickhouse_utils.lua
        filter.options[1] = {
            value = 1,
            label = i18n('policy.drop')
        }
        filter.options[2] = {
            value = 2,
            label = i18n('policy.pass')
        }
    elseif filter_def.value_type == "flow_risk" then
        filter.value_type = 'array'
        filter.options = {}
        local flow_risk_list = ntop.getRiskList() or {}
        if table.len(flow_risk_list) > 0 then
            flow_risk_list[1] = i18n("flow_risk.ndpi_no_risk")
        end
        for id, info in pairsByValues(flow_risk_list, asc) do
            filter.options[#filter.options + 1] = {
                value = id - 1,
                label = info
            }
        end
    elseif filter_def.value_type == "tag_id" then
        filter.value_type = 'array'
        filter.options = {}
        for _, lbl in ipairs(tag_badge_utils.getTags()) do
            filter.options[#filter.options + 1] = {
                value = lbl.id,
                label = lbl.name
            }
        end
    elseif filter_def.value_type == "host_pool_id" or filter_def.value_type == "host_pool" then
        filter.value_type = 'array'
        filter.options = {}
        local host_pools_instance = host_pools:create()
        local host_pools_stats = interface.getHostPoolsStats()
        local host_pool_list = {}
        for pool_id, _ in pairs(host_pools_stats) do
            local label = host_pools_instance:get_pool_name(pool_id)
            filter.options[#filter.options + 1] = {
                value = pool_id,
                label = label
            }
        end
    elseif filter_def.value_type == "minor_connection_state" then
        local flow_consts = require "flow_consts"
        filter.value_type = 'array'
        filter.options = {}
        for state, id in pairs(flow_consts.minor_connection_states) do
            -- EXCLUDE NO_STATE
            if (id ~= 0) then
                filter.options[#filter.options + 1] = {
                    value = id,
                    label = i18n(string.format("db_search.flowfilters.minor_connection_states.%u", id))
                }
            end
        end
    elseif filter_def.value_type == "major_connection_state" then
        local flow_consts = require "flow_consts"
        filter.value_type = 'array'
        filter.options = {}
        for state, id in pairs(flow_consts.major_connection_states) do
            -- EXCLUDE NO_STATE
            if (id ~= 0) then
                filter.options[#filter.options + 1] = {
                    value = id,
                    label = i18n(string.format("flow_fields_description.major_connection_states.%u", id))
                }
            end
        end
    elseif filter_def.value_type == "traffic_direction" then
        filter.value_type = 'array'
        filter.options = {}
        for _, v in pairsByField(flowfilter_utils.traffic_direction, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = v.id,
                label = v.label
            }
        end
    elseif filter_def.value_type == "confidence" then
        filter.value_type = 'array'
        filter.options = {}
        for _, v in pairsByField(flowfilter_utils.confidence, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = v.id,
                label = v.label
            }
        end
    elseif filter_def.value_type == "http_return" then
        filter.value_type = 'array'
        filter.options = {}
        for _, v in pairsByField(flowfilter_utils.http_return, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = v.id,
                label = v.label
            }
        end
    elseif filter_def.value_type == "http_method" then
        filter.value_type = 'array'
        filter.options = {}
        for _, v in pairsByField(flowfilter_utils.http_method, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = v.id,
                label = v.label
            }
        end
    elseif filter_def.value_type == "location" then
        filter.value_type = 'array'
        filter.options = {}
        for _, v in pairsByField(flowfilter_utils.location, 'label', asc) do
            filter.options[#filter.options + 1] = {
                value = v.id,
                label = v.label
            }
        end
    elseif filter_def.value_type == "l4_proto" then
        filter.value_type = 'array'
        filter.options = {}
        local l4_protocol_list = require "l4_protocol_list"

        local l4_protocols = l4_protocol_list.l4_keys

        local list = {}

        for _, proto in pairs(l4_protocols) do
            -- add L4 proto only
            if proto[2] ~= 'ip' and proto[2] ~= 'ipv6' then
                list[proto[1]] = proto[3]
            end
        end

        for name, id in pairsByKeys(list, asc) do
            filter.options[#filter.options + 1] = {
                value = id,
                label = name
            }
        end
    elseif filter_def.value_type == "l7_proto" then
        filter.value_type = 'array'
        filter.options = {}
        local l7_protocols = interface.getnDPIProtocols()
        for name, id in pairsByKeys(l7_protocols, asc) do
            filter.options[#filter.options + 1] = {
                value = id,
                label = name
            }
        end
    elseif filter_def.value_type == "l7_category" then
        filter.value_type = 'array'
        filter.options = {}
        local l7_categories = interface.getnDPICategories()
        for name, id in pairsByKeys(l7_categories, asc) do
            filter.options[#filter.options + 1] = {
                value = id,
                label = getCategoryLabel(name, id)
            }
        end
    elseif filter_def.value_type == "network_id" then
        filter.options = {}
        local networks_stats = interface.getNetworksStats()
        for n, ns in pairs(networks_stats) do
            filter.options[#filter.options + 1] = {
                value = ns.network_id,
                label = getFullLocalNetworkName(ns.network_key)
            }
        end
    elseif filter_def.value_type == "observation_point_id" then
        filter.value_type = 'array'
        filter.options = {}
        local obs_points = interface.getObsPointsInfo()
        local obs_points_list = {}
        for _, stats in pairs(obs_points["ObsPoints"] or {}) do
            obs_points_list[#obs_points_list + 1] = {
                alias = getFullObsPointName(stats["obs_point"]),
                id = stats["obs_point"]
            }
        end
        for _, v in pairsByField(obs_points_list, 'alias', asc) do
            filter.options[#filter.options + 1] = {
                value = v.id,
                label = v.alias
            }
        end
    elseif filter_def.value_type == "country" then
        local country_codes = require "country_codes"
        filter.value_type = 'array'
        filter.options = {}
        for code, label in pairsByValues(country_codes, asc) do
            local id = code
            -- if entity == nil then -- historical flows
            --   id = interface.convertCountryCode2U16(code)
            -- end
            filter.options[#filter.options + 1] = {
                value = id,
                label = label
            }
        end
    elseif filter_def.value_type == "vlan_id" then
        filter.options = {}
        local vlans = interface.getVLANsList()

        if vlans == nil then
            vlans = {
                VLANs = {}
            }
        end
        vlans = vlans["VLANs"]
        for _, vlan in pairs(vlans) do
            local vlan_name = getFullVlanName(vlan["vlan_id"])
            if isEmptyString(vlan_name) then
                vlan_name = i18n('no_vlan')
            end
            filter.options[#filter.options + 1] = {
                value = vlan["vlan_id"],
                label = vlan_name
            }
        end
    elseif filter_def.value_type == "probe_ip" then
        local site_utils = require "site_utils"
        filter.options = {}
        local full_dev_list = {}

        -- Add both Flow devices
        if interface.getFlowDevices then -- Pro Only
            for exporter_ip, _ in pairs(getExporterList()) do
                local group = nil
                if ntop.isEnterpriseM and ntop.isEnterpriseM() then
                  group = site_utils.mapHostToSite(exporter_ip).name
                end
                local probe_name = getProbeName(exporter_ip)
                full_dev_list[exporter_ip] = {
                    value = exporter_ip,
                    label = probe_name,
                    display_more_filters = true,
                    group = group
                }
            end
        end
        -- And sFlow devices
        if interface.getSFlowDevices then -- Pro Only
            for interface, device_list in pairs(interface.getSFlowDevices() or {}) do
                for probe, _ in pairsByValues(device_list or {}, asc) do
                    local group = nil
                    if ntop.isEnterpriseM and ntop.isEnterpriseM() then
                       group = site_utils.mapHostToSite(exporter_ip).name
                    end
                    local probe_name = getProbeName(probe)
                    -- local label = format_name_value(probe_name, probe)
                    full_dev_list[probe] = {
                        value = probe,
                        label = probe_name,
                        display_more_filters = true,
                        group = group
                    }
                end
            end
        end

        for _, device_info in pairsByKeys(full_dev_list, asc) do
            filter.options[#filter.options + 1] = device_info
        end
    elseif filter_def.value_type == "site" then
        filter.value_type = 'array'
        filter.options = {}
        local site_utils = require "site_utils"
        local sites = site_utils.getSites() or {}
        if id == 'site' then -- exporter site
           -- check if exporters are available, otherwise skip filters
           local exporters = interface.getFlowDevices() or {}
           if table.len(exporters) == 0 then sites = {} end
        end
        if #sites > 0 then
            table.sort(sites, function(a, b)
                if a.reserved ~= b.reserved then return a.reserved end
                return a.name < b.name
            end)
            for _, site in pairs(sites) do
                filter.options[#filter.options + 1] = {
                    value = site.id,
                    label = site.name
                }
            end
        end
    elseif filter_def.value_type == "ip_version" then
        filter.value_type = 'array'
        filter.options = {}
        filter.options[#filter.options + 1] = {
            value = "4",
            label = i18n("ipv4")
        }
        filter.options[#filter.options + 1] = {
            value = "6",
            label = i18n("ipv6")
        }
    elseif filter_def.value_type == "role" then
        filter.value_type = 'array'
        filter.options = {}
        filter.options[#filter.options + 1] = {
            value = "attacker",
            label = i18n("attacker")
        }
        filter.options[#filter.options + 1] = {
            value = "victim",
            label = i18n("victim")
        }
        filter.options[#filter.options + 1] = {
            value = "no_attacker_no_victim",
            label = i18n("no_attacker_no_victim")
        }
    elseif filter_def.value_type == "role_cli_srv" then
        filter.value_type = 'array'
        filter.options = {}
        filter.options[#filter.options + 1] = {
            value = "client",
            label = i18n("client")
        }
        filter.options[#filter.options + 1] = {
            value = "server",
            label = i18n("server")
        }
    elseif filter_def.value_type == "alert_status" then
        filter.value_type = 'array'
        filter.options = {}
        for key, info in pairs(alert_consts.alert_status) do
            if info.on_db then
                filter.options[#filter.options + 1] = {
                    value = info.alert_status_id,
                    label = i18n(info.i18n_title)
                }
            end
        end
    elseif filter_def.value_type == "severity" then
        filter.value_type = 'array'
        filter.options = {}
        for _, severity in pairsByField(alert_consts.get_printable_severities(), "severity_id", asc) do
            filter.options[#filter.options + 1] = {
                value = severity.severity_id,
                label = i18n(severity.i18n_title)
            }
        end
    elseif filter_def.value_type == "iface_role" then
        local snmp_utils = require "snmp_utils"
        filter.value_type = 'array'
        filter.options = {}
        local snmp_roles = snmp_utils.get_snmp_interface_role_options()
        for _, role in pairs(snmp_roles) do

            filter.options[#filter.options + 1] = {
                value = role.id,
                label = role.label
            }
        end
    elseif filter_def.value_type == "snmp_interface" then
        if ntop.isPro and ntop.isPro() then
            filter.value_type = 'array'

            if snmp_filter_options_cache then
                filter.options = snmp_filter_options_cache
            else
                filter.options = {}
                local flow_devices = {}
                local interfaces_list = {}
                local probe_ip_requested = nil
                -- Active flow devices
                if (restrict_filters and not isEmptyString(_GET["probe_ip"])) then
                    local tmp = split(_GET["probe_ip"], ";")
                    probe_ip_requested = tmp[1]
                    flow_devices = {
                        [tmp[1]] = 1
                    }
                else
                    local tmp = interface.getFlowDevices()
                    for _, dev_list in pairs(tmp) do
                        for _, exporter_info in pairs(dev_list) do
                            flow_devices[exporter_info.exporter_ip] = 1
                        end
                    end
                end

                -- SNMP devices
                local snmp_cached_dev = require "snmp_cached_dev"
                local snmp_config = require "snmp_config"
                local site_utils = require "site_utils"
                local devices = {}
                local group_cache = {}
                local total = 0
                local current_total_interfaces = 0

                if isEmptyString(probe_ip_requested) then
                    devices = snmp_config.get_all_configured_devices()
                else
                    devices = flow_devices
                end

                -- use pairsByKeys to impose order
                for probe_ip, _ in pairsByKeys(devices) do
                    if flow_devices[probe_ip] then
                        -- Use SNMP info, remove from flow devices list
                        flow_devices[probe_ip] = nil
                    end
                    local cached_interfaces = snmp_cached_dev:get_interfaces_with_counters(probe_ip)
                    local probe_label

                    if not isEmptyString(probe_ip) then
                        probe_label = getProbeName(probe_ip)
                    end

                    if isEmptyString(probe_label) then
                        probe_label = probe_ip
                    end

                    if cached_interfaces and cached_interfaces["interfaces"] then
                        local interfaces = cached_interfaces["interfaces"]
                        local group = nil
                        current_total_interfaces = current_total_interfaces + table.len(interfaces)

                        -- Fallback, too many interfaces
                        if current_total_interfaces > MAX_NUM_ENTRIES then
                            goto maxEntriesFallback
                        end

                        if ntop.isEnterpriseM and ntop.isEnterpriseM() then
                            group = site_utils.mapHostToSite(exporter_ip).name
                            group_cache[probe_ip] = group
                        end

                        for if_index, if_info in pairs(interfaces) do
                            local counters = cached_interfaces.if_counters[tostring(if_index)]
                            local good_iface = false

                            if (counters ~= nil) then
                                if ((counters.inb > 0) or (counters.outb > 0)) then
                                    -- The interface made some traffic
                                    good_iface = true
                                end
                            end

                            -- Skip interfaces down or with no traffic
                            if (good_iface and (tonumber(if_info.admin_status) == 1) and (tonumber(if_info.status) == 1) -- operational status
                            ) then
                                local label = format_portidx_name(probe_ip, if_index, true)

                                if not hide_exporters_name then
                                    label = probe_label .. ' - ' .. label
                                end

                                interfaces_list[label] = {
                                    value = probe_ip .. "_" .. if_index,
                                    label = label,
                                    show_only_value = probe_ip,
                                    group = group
                                }
                            end
                        end
                    end
                end

                for exporter_ip, _ in pairs(flow_devices or {}) do
                    -- Add interfaces for flow devices which are not polled by SNMP
                    local interfaces = interface.getFlowDeviceInfoByIP(exporter_ip)
                    local group = nil
                    current_total_interfaces = current_total_interfaces + table.len(interfaces)

                    -- Fallback, too many interfaces
                    if current_total_interfaces > MAX_NUM_ENTRIES then
                        goto maxEntriesFallback
                    end

                    if ntop.isEnterpriseM and ntop.isEnterpriseM() then
                        group = group_cache[exporter_ip] -- use cache first
                        
                        if (group == nil) then
                            group = site_utils.mapHostToSite(exporter_ip).name
                            group_cache[exporter_ip] = group
                        end
                    end

                    for _, interfaces_table in pairs(interfaces or {}) do
                        for if_index, _ in pairsByKeys(interfaces_table) do
                            local label = format_portidx_name(exporter_ip, if_index, true)

                            if not hide_exporters_name then
                                label = exporter_ip .. ' - ' .. label
                            end

                            interfaces_list[tostring(label)] = {
                                value = exporter_ip .. "_" .. if_index,
                                label = label,
                                show_only_value = exporter_ip,
                                group = group
                            }
                        end
                    end
                end

                ::maxEntriesFallback::
                -- Fallback, too many interfaces, just send the ones with some
                if current_total_interfaces > MAX_NUM_ENTRIES then
                    local exporters_utils = require "exporters_utils"
                    local exporters_interfaces_list = exporters_utils.getAllInterfacesList(true)
                    for _, value in pairs(exporters_interfaces_list or {}) do
                        local label = value.interface_name
                        if not hide_exporters_name then
                            label = value.exporter_name .. ' - ' .. label
                        end
                        interfaces_list[tostring(value.interface_name)] = {
                            value = value.exporter_ip .. "_" .. value.interface_id,
                            label = label,
                            show_only_value = value.exporter_ip,
                            group = ternary(value.role, value.role.label, "")
                        }
                    end
                end

                for _, values in pairsByKeys(interfaces_list, asc) do
                    filter.options[#filter.options + 1] = values
                end

                snmp_filter_options_cache = filter.options
            end
        end
    end

    if changed_ifid then
        interface.select(current_ifid)
    end

    return filter
end

-- ######################################

function flowfilter_utils.add_flowfilter_if_valid(filters, filter_key, operators, i18n_prefix)
    if isEmptyString(_GET[filter_key]) then
        return
    end

    local get_value = _GET[filter_key]
    local list = split(get_value, ',')

    for _, item in ipairs(list) do
        local selected_operator = 'eq'

        local splitted = split(item, flowfilter_utils.SEPARATOR)

        local realValue
        if #splitted == 2 then
            realValue = splitted[1]
            selected_operator = splitted[2]
        end

        local value = realValue
        if flowfilter_utils.formatters[filter_key] ~= nil then
            value = flowfilter_utils.formatters[filter_key](value)
        end

        local filter_item = {
            realValue = realValue,
            value = value,
            label = i18n(i18n_prefix .. "." .. filter_key),
            key = filter_key,
            operators = operators,
            selectedOperator = selected_operator
        }

        table.insert(filters, filter_item)
    end
end

-- #####################################

function flowfilter_utils.build_bpf(filters)
    local bpf = ""

    local n = 0

    local and_filters = {}
    local or_filters = {}

    -- Build 'or' groups (same key)
    for key, _value in pairs(filters) do
        if not flowfilter_utils.defined_filters[key] then
            goto skip_filter
        end
        local bpf_key = flowfilter_utils.defined_filters[key].bpf_key

        if not bpf_key then
            goto skip_filter
        end

        local list = split(_value, ',')

        for _, value in ipairs(list) do
            local op = "eq" -- default
            local bpf_val = value

            -- filters has value formatted in this way: (e.g.) cli_port = 888,eq
            -- it means, search for values with port == 888
            local splitted_value = split(value, flowfilter_utils.SEPARATOR)

            if table.len(splitted_value) == 2 then
                op = splitted_value[2]
                bpf_val = splitted_value[1]
            end

            local version = 4
            if key:ends('ip') then -- either cli_ip, srv_ip or ip (for both)
                version = isIPv6(bpf_val) and 6 or 4
            end

            if key == "l4proto" and bpf_val and not tonumber(bpf_val) then
                bpf_val = l4_proto_to_id(bpf_val)
            end

            -- Fetch the clickhouse key

            if op ~= "eq" and op ~= "neq" then
                goto continue
            end

            local cond = bpf_key .. ' ' .. bpf_val

            if op == "neq" then
                cond = 'not' .. ' ' .. cond
            end

            if op == "neq" then -- All 'neq' with the same key are in 'and'
                if and_filters[key] then
                    and_filters[key] = and_filters[key] .. " AND " .. cond
                else
                    and_filters[key] = cond
                end
            else -- All other operators with the same key are in 'or'
                if or_filters[key] then
                    or_filters[key] = or_filters[key] .. " OR " .. cond
                else
                    or_filters[key] = cond
                end
            end

            n = n + 1

            ::continue::
        end

        ::skip_filter::
    end

    if n == 0 then
        return bpf
    end

    -- Join all groups with 'and'

    -- AND groups
    for key, value in pairs(and_filters) do
        if isEmptyString(bpf) then
            bpf = "(" .. value .. ")"
        else
            bpf = bpf .. " and " .. "(" .. value .. ")"
        end
    end

    -- OR groups
    for key, value in pairs(or_filters) do
        if isEmptyString(bpf) then
            bpf = "(" .. value .. ")"
        else
            bpf = bpf .. " and " .. "(" .. value .. ")"
        end
    end

    return bpf
end

-- #####################################

-- given a flowfilter key, returns the associated formatted i18n value
function flowfilter_utils.get_flowfilter_i18n(filter_name)
    local filter_def = flowfilter_utils.defined_filters[filter_name]
    if filter_def == nil then
        return nil
    end

    return filter_def.i18n_label
end

-- #####################################

return flowfilter_utils
