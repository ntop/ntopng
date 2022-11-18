--
-- (C) 2014-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"

local timeseries_info = {}

-- #################################

local series_extra_info = {
  alerts = {
    color = '#2d99bd'
  },
  bytes = {
    color = '#ffc046'
  },
  bytes_sent = {
    color = '#c6d9fd'
  },
  bytes_rcvd = {
    color = '#90ee90'
  },
  devices = {
    color = '#ac9ddf'
  },
  flows = {
    color = '#8c6f94'
  },
  hosts = {
    color = '#ff7f0e'
  },
  score = {
    color = '#ff3231'
  },
  cli_score = {
    color = '#690504'
  },
  srv_score = {
    color = '#f5a2a2'
  },
  default = {
    color = '#c6d9fd'
  }
}

-- #################################

local timeseries_id = {
  iface = "iface",
  host  = "host",
  mac   = "mac",
  network = "subnet",
  asn = "asn",
  country = "country",
  os = "os",
  vlan = "vlan",
  host_pool = "host_pool",
  pod = "pod",
  container = "container",
  hash_state = "ht",
  system = "system",
  profile = "profile",
  redis = "redis",
  influxdb = "influxdb",
  active_monitoring = "am",
  snmp = "snmp_dev"
}

-- #################################

function timeseries_info.get_timeseries_color(subject)
  if series_extra_info[subject] then
    return series_extra_info[subject].color
  end

  -- Safety check, if an improper value is given, 
  -- then return a default color
  return series_extra_info.default.color
end

-- #################################

-- Timeseries list
local community_timeseries = {
  { schema = "iface:traffic_rxtx",            id = timeseries_id.iface, label = i18n("graphs.traffic_rxtx"),              priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "iface:flows",                   id = timeseries_id.iface, label = i18n("graphs.active_flows"),              priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:new_flows",               id = timeseries_id.iface, label = i18n("graphs.new_flows"),                 priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { new_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:alerted_flows",           id = timeseries_id.iface, label = i18n("graphs.total_alerted_flows"),       priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:hosts",                   id = timeseries_id.iface, label = i18n("graphs.active_hosts"),              priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.hosts'), timeseries = { num_hosts          = { label = i18n('graphs.metric_labels.num_hosts'),   color = timeseries_info.get_timeseries_color('hosts') }}},
  { schema = "iface:engaged_alerts",          id = timeseries_id.iface, label = i18n("graphs.engaged_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { engaged_alerts     = { label = i18n('graphs.engaged_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},
  { schema = "iface:dropped_alerts",          id = timeseries_id.iface, label = i18n("graphs.dropped_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { dropped_alerts     = { label = i18n('graphs.dropped_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},
  { schema = "iface:devices",                 id = timeseries_id.iface, label = i18n("graphs.active_devices"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.devices'), timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_devices'), color = timeseries_info.get_timeseries_color('devices') }}},
  { schema = "iface:http_hosts",              id = timeseries_id.iface, label = i18n("graphs.active_http_servers"),       priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.servers'), timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_servers'), color = timeseries_info.get_timeseries_color('devices') }},  nedge_exclude = true },
  { schema = "iface:traffic",                 id = timeseries_id.iface, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.traffic'),     color = timeseries_info.get_timeseries_color('devices') }},  nedge_exclude = true },
  { schema = "iface:score",                   id = timeseries_id.iface, label = i18n("graphs.score"),                     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.score'), timeseries = { cli_score          = { label = i18n('graphs.cli_score'),                 color = timeseries_info.get_timeseries_color('cli_score') },   srv_score = { label = i18n('graphs.srv_score'), color = timeseries_info.get_timeseries_color('srv_score') }}},
  { schema = "iface:packets_vs_drops",        id = timeseries_id.iface, label = i18n("graphs.packets_vs_drops"),          priority = 0, measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.metric_labels.packets'),     color = timeseries_info.get_timeseries_color('packets') },     drops = { label = i18n('graphs.metric_labels.drops'), draw_type = "line", color = timeseries_info.get_timeseries_color('default') }}},
  { schema = "iface:nfq_pct",                 id = timeseries_id.iface, label = i18n("graphs.num_nfq_pct"),               priority = 0, measure_unit = "percentage", scale = 0, timeseries = { num_nfq_pct        = { label = i18n('graphs.num_nfq_pct'),               color = timeseries_info.get_timeseries_color('default') }},  nedge_only = true },
  { schema = "iface:hosts_anomalies",         id = timeseries_id.iface, label = i18n("graphs.hosts_anomalies"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.anomalies'), timeseries = { num_loc_hosts_anom = { label = i18n('graphs.loc_host_anomalies'),        color = timeseries_info.get_timeseries_color('hosts') },       num_rem_hosts_anom = { label = i18n('graphs.rem_host_anomalies'), draw_type = "line", color = timeseries_info.get_timeseries_color('hosts') }}},
  { schema = "iface:disc_prob_bytes",         id = timeseries_id.iface, label = i18n("graphs.discarded_probing_bytes"),   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.drops'),       color = timeseries_info.get_timeseries_color('bytes') }},    nedge_exclude = true },
  { schema = "iface:disc_prob_pkts",          id = timeseries_id.iface, label = i18n("graphs.discarded_probing_packets"), priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets            = { label = i18n('graphs.metric_labels.drops'),       color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:dumped_flows",            id = timeseries_id.iface, label = i18n("graphs.dumped_flows"),              priority = 0, measure_unit = "fps",    scale = 0, timeseries = { dumped_flows       = { label = i18n('graphs.dumped_flows'),              color = timeseries_info.get_timeseries_color('flows') },       dropped_flows = { label = i18n('graphs.dumped_flows'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:zmq_recv_flows",          id = timeseries_id.iface, label = i18n("graphs.zmq_received_flows"),        priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { flows              = { label = i18n('graphs.zmq_received_flows'),        color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:zmq_flow_coll_drops",     id = timeseries_id.iface, label = i18n("graphs.zmq_flow_coll_drops"),       priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { drops              = { label = i18n('graphs.zmq_flow_coll_drops'),       color = timeseries_info.get_timeseries_color('default') }},  nedge_exclude = true },
  { schema = "iface:zmq_flow_coll_udp_drops", id = timeseries_id.iface, label = i18n("graphs.zmq_flow_coll_udp_drops"),   priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { drops              = { label = i18n('graphs.zmq_flow_coll_udp_drops'),   color = timeseries_info.get_timeseries_color('default') }},  nedge_exclude = true },
  { schema = "iface:tcp_lost",                id = timeseries_id.iface, label = i18n("graphs.tcp_packets_lost"),          priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_lost'),          color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_out_of_order",        id = timeseries_id.iface, label = i18n("graphs.tcp_packets_ooo"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_ooo'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_retransmissions",     id = timeseries_id.iface, label = i18n("graphs.tcp_packets_retr"),          priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_retr'),          color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_keep_alive",          id = timeseries_id.iface, label = i18n("graphs.tcp_packets_keep_alive"),    priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_keep_alive'),    color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_syn",                 id = timeseries_id.iface, label = i18n("graphs.tcp_syn_packets"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_syn_packets'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_synack",              id = timeseries_id.iface, label = i18n("graphs.tcp_synack_packets"),        priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_syn_packets'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_finack",              id = timeseries_id.iface, label = i18n("graphs.tcp_finack_packets"),        priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_finack_packets'),        color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_rst",                 id = timeseries_id.iface, label = i18n("graphs.tcp_rst_packets"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  
  -- host_details.lua (HOST): --
  { schema = "host:traffic",                       id = timeseries_id.host, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "host:score",                         id = timeseries_id.host, label = i18n("graphs.score"),                     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.score'), timeseries = { cli_score          = { label = i18n('graphs.cli_score'),                 color = timeseries_info.get_timeseries_color('cli_score') },   srv_score = { label = i18n('graphs.srv_score'), color = timeseries_info.get_timeseries_color('srv_score') }}},
  { schema = "host:active_flows",                  id = timeseries_id.host, label = i18n("graphs.active_flows"),              priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:total_flows",                   id = timeseries_id.host, label = i18n("graphs.total_flows"),               priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:num_blacklisted_flows",         id = timeseries_id.host, label = i18n("graphs.num_blacklisted_flows"),     priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:alerted_flows",                 id = timeseries_id.host, label = i18n("graphs.total_alerted_flows"),       priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:unreachable_flows",             id = timeseries_id.host, label = i18n("graphs.total_unreachable_flows"),   priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:host_unreachable_flows",        id = timeseries_id.host, label = i18n("graphs.host_unreachable_flows"),    priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:contacts",                      id = timeseries_id.host, label = i18n("graphs.active_host_contacts"),      priority = 0, measure_unit = "fps",    scale = 0, timeseries = { num_as_clients     = { label = i18n('graphs.metric_labels.as_cli'),      color = timeseries_info.get_timeseries_color('flows') },       num_as_server   = { label = i18n('graphs.metric_labels.as_srv'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:contacts_behaviour",            id = timeseries_id.host, label = i18n("graphs.host_contacts_behaviour"),   priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.contacts'), timeseries = { value              = { label = i18n('graphs.score'),                     color = timeseries_info.get_timeseries_color('score') },       lower_bound     = { label = i18n('graphs.lower_bound'), draw_type = "line", color = timeseries_info.get_timeseries_color('score') }, upper_bound = { label = i18n('graphs.upper_bound'), draw_type = "line", color = timeseries_info.get_timeseries_color('score') }}, nedge_exclude = true },
  { schema = "host:total_alerts",                  id = timeseries_id.host, label = i18n("graphs.alerts"),                    priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { alerts             = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:engaged_alerts",                id = timeseries_id.host, label = i18n("graphs.engaged_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { alerts             = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:dns_qry_sent_rsp_rcvd",         id = timeseries_id.host, label = i18n("graphs.dns_qry_sent_rsp_rcvd"),     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.queries'), timeseries = { queries_pkts       = { label = i18n('graphs.metric_labels.queries_pkts'),color = timeseries_info.get_timeseries_color('default') },     replies_ok_pkts = { label = i18n('graphs.metric_labels.ok_pkts'), color = timeseries_info.get_timeseries_color('default') }, replies_error_pkts = { label = i18n('graphs.metric_labels.error_pkts'), color = timeseries_info.get_timeseries_color('default') }}},
  { schema = "host:dns_qry_rcvd_rsp_sent",         id = timeseries_id.host, label = i18n("graphs.dns_qry_rcvd_rsp_sent"),     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.queries'), timeseries = { queries_pkts       = { label = i18n('graphs.metric_labels.queries_pkts'),color = timeseries_info.get_timeseries_color('default') },     replies_ok_pkts = { label = i18n('graphs.metric_labels.ok_pkts'), color = timeseries_info.get_timeseries_color('default') }, replies_error_pkts = { label = i18n('graphs.metric_labels.error_pkts'), color = timeseries_info.get_timeseries_color('default') }}},
  { schema = "host:tcp_rx_stats",                  id = timeseries_id.host, label = i18n("graphs.tcp_rx_stats"),              priority = 0, measure_unit = "pps",    scale = 0, timeseries = { retran_pkts        = { label = i18n('graphs.metric_labels.retra_pkts'),  color = timeseries_info.get_timeseries_color('packets') },     out_of_order_pkts = { label = i18n('graphs.metric_labels.ooo_pkts'), color = timeseries_info.get_timeseries_color('packets') }, lost_packets = { label = i18n('graphs.metric_labels.lost_pkts'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:tcp_tx_stats",                  id = timeseries_id.host, label = i18n("graphs.tcp_tx_stats"),              priority = 0, measure_unit = "pps",    scale = 0, timeseries = { retran_pkts        = { label = i18n('graphs.metric_labels.retra_pkts'),  color = timeseries_info.get_timeseries_color('packets') },     out_of_order_pkts = { label = i18n('graphs.metric_labels.ooo_pkts'), color = timeseries_info.get_timeseries_color('packets') }, lost_packets = { label = i18n('graphs.metric_labels.lost_pkts'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:udp_pkts",                      id = timeseries_id.host, label = i18n("graphs.udp_packets"),               priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:echo_reply_packets",            id = timeseries_id.host, label = i18n("graphs.echo_reply_packets"),        priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:echo_packets",                  id = timeseries_id.host, label = i18n("graphs.echo_request_packets"),      priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:tcp_packets",                   id = timeseries_id.host, label = i18n("graphs.tcp_packets"),               priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:udp_sent_unicast",              id = timeseries_id.host, label = i18n("graphs.udp_sent_unicast_vs_non_unicast"), priority = 0, measure_unit = "bps", scale = 0, timeseries = { bytes_sent_unicast = { label = i18n('graphs.metric_labels.sent_uni'), color = timeseries_info.get_timeseries_color('bytes') },       bytes_sent_non_uni = { label = i18n('graphs.metric_labels.sent_non_uni'), color = timeseries_info.get_timeseries_color('bytes') }}},
  { schema = "host:dscp",                          id = timeseries_id.host, label = i18n("graphs.dscp_classes"),              priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes') },       bytes_rcvd      = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }}},
  { schema = "host:host_tcp_unidirectional_flows", id = timeseries_id.host, label = i18n("graphs.unidirectional_tcp_flows"),  priority = 0, measure_unit = "fps",scale = 0, timeseries = { flows_as_client         = { label = i18n('graphs.flows_as_client'),      color = timeseries_info.get_timeseries_color('flows') },  flows_as_server      = { label = i18n('graphs.flows_as_server'),    color = timeseries_info.get_timeseries_color('flows') }}},

  -- mac_details.lua (MAC): --
  { schema = "mac:traffic",                   id = timeseries_id.mac, label = i18n("graphs.traffic"), priority = 0, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes_sent') }, bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },

  -- network_details.lua (SUBNET): --
  { schema = "subnet:traffic",                id = timeseries_id.network, label = i18n("graphs.traffic"),               measure_unit = "bps", scale = 0, timeseries = { bytes_egress = { label = i18n('graphs.metrics_suffixes.egress') }, bytes_ingress = { label = i18n('graphs.metrics_suffixes.ingress') }, bytes_inner = { label = i18n('graphs.metrics_suffixes.inner') }}, default_visible = true },
  { schema = "subnet:broadcast_traffic",      id = timeseries_id.network, label = i18n("broadcast_traffic"),            measure_unit = "bps", scale = 0, timeseries = { bytes_egress = { label = i18n('graphs.metrics_suffixes.egress') }, bytes_ingress = { label = i18n('graphs.metrics_suffixes.ingress') }, bytes_inner = { label = i18n('graphs.metrics_suffixes.inner') }} },
  { schema = "subnet:engaged_alerts",         id = timeseries_id.network, label = i18n("show_alerts.engaged_alerts"),   measure_unit = "number", scale = 0, timeseries = { alerts = { label = i18n('graphs.engaged_alerts') }} },
  { schema = "subnet:score",                  id = timeseries_id.network, label = i18n("score"),                        measure_unit = "number", scale = 0, timeseries = { score = { label = i18n('score') }, scoreAsClient = { label = i18n('score_as_client') }, scoreAsServer = { label = i18n('score_as_server') } }},
  { schema = "subnet:tcp_retransmissions",    id = timeseries_id.network, label = i18n("graphs.tcp_packets_retr"),      measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
  { schema = "subnet:tcp_out_of_order",       id = timeseries_id.network, label = i18n("graphs.tcp_packets_ooo"),       measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
  { schema = "subnet:tcp_lost",               id = timeseries_id.network, label = i18n("graphs.tcp_packets_lost"),      measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
  { schema = "subnet:tcp_keep_alive",         id = timeseries_id.network, label = i18n("graphs.tcp_packets_keep_alive"),measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
  
  -- as_details.lua (ASN): --
  { schema = "asn:traffic",                   id = timeseries_id.asn, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "asn:rtt",                       id = timeseries_id.asn, label = i18n("graphs.rtt"),                       priority = 0, measure_unit = "ms",     scale = 0, timeseries = { millis_rtt         = { label = i18n('graphs.metric_labels.rtt'),         color = timeseries_info.get_timeseries_color('default') } }, nedge_exclude = true },
  { schema = "asn:traffic_sent",              id = timeseries_id.asn, label = i18n("graphs.traffic_sent"),              priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') } }, nedge_exclude = true },
  { schema = "asn:traffic_rcvd",              id = timeseries_id.asn, label = i18n("graphs.traffic_rcvd"),              priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.rcvd'),        color = timeseries_info.get_timeseries_color('bytes_rcvd') } }, nedge_exclude = true },
  { schema = "asn:score",                     id = timeseries_id.asn, label = i18n("graphs.score"),                     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.score'),   timeseries = { score = { label = i18n('graphs.metric_labels.score'), color = timeseries_info.get_timeseries_color('score') }, cli_score = { label = i18n('graphs.metric_labels.cli_score'), color = timeseries_info.get_timeseries_color('cli_score') }, srv_score = { label = i18n('graphs.metric_labels.srv_score'), color = timeseries_info.get_timeseries_color('srv_score') } }},
  { schema = "asn:tcp_retransmissions",       id = timeseries_id.asn, label = i18n("graphs.tcp_packets_retr"),          priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets_sent = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('packets') }, packets_rcvd = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "asn:tcp_keep_alive",            id = timeseries_id.asn, label = i18n("graphs.tcp_packets_keep_alive"),    priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets_sent = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('packets') }, packets_rcvd = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "asn:tcp_out_of_order",          id = timeseries_id.asn, label = i18n("graphs.tcp_packets_ooo"),           priority = 0, measure_unit = "number", scale = i18n('graphs.tcp_packets_ooo'),       timeseries = { packets_sent = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('packets') }, packets_rcvd = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "asn:tcp_lost",                  id = timeseries_id.asn, label = i18n("graphs.tcp_packets_lost"),          priority = 0, measure_unit = "number", scale = i18n('graphs.tcp_packets_lost'),      timeseries = { packets_sent = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('packets') }, packets_rcvd = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },  

  -- country_details.lua (Country): --
  { schema = "country:traffic",               id = timeseries_id.country, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_egress = { label = i18n('graphs.metrics_suffixes.egress') }, bytes_ingress = { label = i18n('graphs.metrics_suffixes.ingress') }, bytes_inner = { label = i18n('graphs.metrics_suffixes.inner') }}, default_visible = true },
  { schema = "country:score",                 id = timeseries_id.country, label = i18n("score"),                            priority = 0, measure_unit = "number", scale = 0, timeseries = { score = { label = i18n('score') }, scoreAsClient = { label = i18n('score_as_client') }, scoreAsServer = { label = i18n('score_as_server') } }},

  -- os_details.lua (Operative System): --
  { schema = "os:traffic",                    id = timeseries_id.os, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_egress = { label = i18n('graphs.metrics_suffixes.egress') }, bytes_ingress = { label = i18n('graphs.metrics_suffixes.ingress') }}, default_visible = true },
  
  -- vlan_details.lua (VLAN): --
  { schema = "vlan:traffic",                  id = timeseries_id.vlan, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "vlan:score",                    id = timeseries_id.vlan, label = i18n("score"),                            priority = 0, measure_unit = "number", scale = 0, timeseries = { score = { label = i18n('score') }, scoreAsClient = { label = i18n('score_as_client') }, scoreAsServer = { label = i18n('score_as_server') } }},

  -- pool_details.lua (Host Pool): --
  { schema = "host_pool:traffic",             id = timeseries_id.host_pool, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "host_pool:blocked_flows",       id = timeseries_id.host_pool, label = i18n("graphs.blocked_flows"),             priority = 0, measure_unit = "number", scale = 0, timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "host_pool:hosts",               id = timeseries_id.host_pool, label = i18n("graphs.active_hosts"),              priority = 0, measure_unit = "number", scale = 0, timeseries = { num_hosts          = { label = i18n('graphs.metric_labels.num_hosts'),   color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "host_pool:devices",             id = timeseries_id.host_pool, label = i18n("graphs.active_devices"),            priority = 0, measure_unit = "number", scale = 0, timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_devices'), color = timeseries_info.get_timeseries_color('default') } } },

  -- pod_details.lua (Pod): --
  { schema = "pod:num_flows",                 id = timeseries_id.pod, label = i18n("graphs.active_flows"),              priority = 0, measure_unit = "fps",    scale = 0, timeseries = { as_client          = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },  as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "pod:num_containers",            id = timeseries_id.pod, label = i18n("containers_stats.containers"),      priority = 0, measure_unit = "number", scale = 0, timeseries = { num_containers     = { label = i18n('graphs.metric_labels.num_containers'), color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "pod:rtt",                       id = timeseries_id.pod, label = i18n("containers_stats.avg_rtt"),         priority = 0, measure_unit = "ms",     scale = 0, timeseries = { as_client          = { label = i18n('graphs.rtt_as_client'),             color = timeseries_info.get_timeseries_color('default') },  as_server = { label = i18n('graphs.rtt_as_server'), color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "pod:rtt_variance",              id = timeseries_id.pod, label = i18n("containers_stats.avg_rtt_variance"),priority = 0, measure_unit = "ms",     scale = 0, timeseries = { as_client          = { label = i18n('graphs.variance_as_client'),        color = timeseries_info.get_timeseries_color('default') },  as_server = { label = i18n('graphs.variance_as_server'), color = timeseries_info.get_timeseries_color('default') } } },

  -- container_details.lua (Container): --
  { schema = "container:num_flows",           id = timeseries_id.container, label = i18n("graphs.active_flows"),              priority = 0, measure_unit = "fps",    scale = 0, timeseries = { as_client          = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },  as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "container:rtt",                 id = timeseries_id.container, label = i18n("containers_stats.avg_rtt"),         priority = 0, measure_unit = "ms",     scale = 0, timeseries = { as_client          = { label = i18n('graphs.rtt_as_client'),             color = timeseries_info.get_timeseries_color('default') },  as_server = { label = i18n('graphs.rtt_as_server'), color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "container:rtt_variance",        id = timeseries_id.container, label = i18n("containers_stats.avg_rtt_variance"),priority = 0, measure_unit = "ms",     scale = 0, timeseries = { as_client          = { label = i18n('graphs.variance_as_client'),        color = timeseries_info.get_timeseries_color('default') },  as_server = { label = i18n('graphs.variance_as_server'), color = timeseries_info.get_timeseries_color('default') } } },
  
  -- hash_table_details.lua (Hash Table): --
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("about.cpu_load"),                   priority = 0, measure_unit = "number", ts_query = "CountriesHash",        scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("hash_table.HostHash"),              priority = 0, measure_unit = "number", ts_query = "HostHash",             scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("hash_table.MacHash"),               priority = 0, measure_unit = "number", ts_query = "MacHash",              scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("hash_table.FlowHash"),              priority = 0, measure_unit = "number", ts_query = "FlowHash",             scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("hash_table.AutonomousSystemHash"),  priority = 0, measure_unit = "number", ts_query = "AutonomousSystemHash", scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("hash_table.ObservationPointHash"),  priority = 0, measure_unit = "number", ts_query = "ObservationPointHash", scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },
  { schema = "ht:state",                      id = timeseries_id.hash_state, label = i18n("hash_table.VlanHash"),              priority = 0, measure_unit = "number", ts_query = "VlanHash",             scale = 0, timeseries = { num_idle           = { label = i18n('graphs.metric_labels.num_idle'),    color = timeseries_info.get_timeseries_color('default') },  num_active = { label = i18n('graphs.metric_labels.num_active'), color = timeseries_info.get_timeseries_color('default') }}, default_visible = true },

  -- system_stats.lua (System Stats): --
  { schema = "system:cpu_states",             id = timeseries_id.system, label = i18n("about.cpu_load"),                   priority = 0, measure_unit = "number", scale = 0, timeseries = { iowait_pct    = { label = i18n('about.iowait'),    color = timeseries_info.get_timeseries_color('default') },  active_pct = { label = i18n('about.active'), color = timeseries_info.get_timeseries_color('default') },  idle_pct    = { label = i18n('about.idle'),    color = timeseries_info.get_timeseries_color('default') } }, default_visible = true },
  { schema = "process:resident_memory",       id = timeseries_id.system, label = i18n("graphs.process_memory"),            priority = 0, measure_unit = "bytes",  scale = 0, timeseries = { resident_bytes = { label = i18n('graphs.metric_labels.bytes'),    color = timeseries_info.get_timeseries_color('bytes') } } },
  { schema = "process:num_alerts",            id = timeseries_id.system, label = i18n("graphs.process_alerts"),            priority = 0, measure_unit = "bytes",  scale = 0, timeseries = { written_alerts    = { label = i18n('about.alerts_stored'),    color = timeseries_info.get_timeseries_color('default') },  alerts_queries = { label = i18n('about.alert_queries'), color = timeseries_info.get_timeseries_color('default') },  dropped_alerts    = { label = i18n('about.alerts_dropped'),    color = timeseries_info.get_timeseries_color('default') } } },
  -- { schema = "iface:engaged_alerts",          id = timeseries_id.system, label = i18n("graphs.engaged_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { engaged_alerts     = { label = i18n('graphs.engaged_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},
  -- { schema = "iface:dropped_alerts",          id = timeseries_id.system, label = i18n("graphs.dropped_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { dropped_alerts     = { label = i18n('graphs.dropped_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},

  -- profile_details.lua (Profile): --
  { schema = "profile:traffic",               id = timeseries_id.profile, label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes    = { label = i18n('graphs.metric_labels.bytes'),      color = timeseries_info.get_timeseries_color('bytes') } } },

  -- redis_monitor.lua (Redis): --
  { schema = "redis:memory",                  id = timeseries_id.redis, label = i18n("about.ram_memory"),                 priority = 0, measure_unit = "bytes",  scale = 0, timeseries = { resident_bytes = { label = i18n('graphs.metric_labels.bytes'),    color = timeseries_info.get_timeseries_color('bytes') } } },
  { schema = "redis:keys",                    id = timeseries_id.redis, label = i18n("system_stats.redis.redis_keys"),    priority = 0, measure_unit = "number", scale = 0, timeseries = { num_keys       = { label = i18n('graphs.metric_labels.keys'),     color = timeseries_info.get_timeseries_color('default') } } },

  -- influxdb_monitor.lua (Influx DB): --
  { schema = "influxdb:storage_size",         id = timeseries_id.influxdb, label = i18n("traffic_recording.storage_utilization"), priority = 0, measure_unit = "bytes", scale = 0, timeseries = { disk_bytes       = { label = i18n('graphs.metric_labels.bytes'),     color = timeseries_info.get_timeseries_color('bytes') } } },
  { schema = "influxdb:memory_size",          id = timeseries_id.influxdb, label = i18n("about.ram_memory"),                      priority = 0, measure_unit = "bytes", scale = 0, timeseries = { mem_bytes        = { label = i18n('graphs.metric_labels.bytes'),     color = timeseries_info.get_timeseries_color('bytes') } } },
  { schema = "influxdb:write_successes",      id = timeseries_id.influxdb, label = i18n("system_stats.write_througput"),          priority = 0, measure_unit = "number",scale = 0, timeseries = { points           = { label = i18n('graphs.metric_labels.num_points'),     color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "influxdb:exports",              id = timeseries_id.influxdb, label = i18n("system_stats.exports_label"),            priority = 0, measure_unit = "number",scale = 0, timeseries = { num_exports      = { label = i18n('system_stats.exports_label'),     color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "influxdb:exported_points",      id = timeseries_id.influxdb, label = i18n("system_stats.exported_points"),          priority = 0, measure_unit = "number",scale = 0, timeseries = { points           = { label = i18n('graphs.metric_labels.num_points'),     color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "influxdb:dropped_points",       id = timeseries_id.influxdb, label = i18n("system_stats.dropped_points"),           priority = 0, measure_unit = "number",scale = 0, timeseries = { points           = { label = i18n('graphs.metric_labels.num_points'),     color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "influxdb:rtt",                  id = timeseries_id.influxdb, label = i18n("graphs.num_ms_rtt"),                     priority = 0, measure_unit = "ms",    scale = 0, timeseries = { millis_rtt       = { label = i18n('graphs.num_ms_rtt'),     color = timeseries_info.get_timeseries_color('default') } } },

  -- active_monitoring.lua (Active Monitoring): --
  { schema = "am_host:val_min",               id = timeseries_id.active_monitoring, label = i18n("graphs.num_ms_rtt"),                     priority = 0, measure_unit = "ms",    scale = 0, timeseries = { value            = { label = i18n('graphs.num_ms_rtt'),     color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "am_host:cicmp_stats_min",       id = timeseries_id.active_monitoring, label = i18n("flow_details.round_trip_time"),          priority = 0, measure_unit = "ms",    scale = 0, timeseries = { min_rtt          = { label = i18n('graphs.min_rtt'),        color = timeseries_info.get_timeseries_color('default') }, max_rtt = { label = i18n('graphs.max_rtt'),        color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "am_host:jitter_stats_min",      id = timeseries_id.active_monitoring, label = i18n("active_monitoring_stats.rtt_vs_jitter"), priority = 0, measure_unit = "ms",    scale = 0, timeseries = { latency          = { label = i18n('flow_details.mean_rtt'), color = timeseries_info.get_timeseries_color('default') }, jitter = { label = i18n('flow_details.rtt_jitter'),        color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "am_host:http_stats_min",        id = timeseries_id.active_monitoring, label = i18n("graphs.http_stats"),                     priority = 0, measure_unit = "ms",    scale = 0, timeseries = { lookup_ms        = { label = i18n('graphs.name_lookup'),    color = timeseries_info.get_timeseries_color('default') }, other_ms = { label = i18n('other'),        color = timeseries_info.get_timeseries_color('default') } } },

  -- active_monitoring.lua (Active Monitoring): --
  { schema = "top:snmp_if:traffic",           id = timeseries_id.snmp, group = i18n("snmp.top"),                         priority = 2, measure_unit = "bps", scale = 0,    timeseries = { bytes_sent  = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes') }, bytes_rcvd = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') } } },
  { schema = "snmp_dev:cpu_states",           id = timeseries_id.snmp, label = i18n("about.cpu_load"),                   priority = 0, measure_unit = "number", scale = 0, timeseries = { user_pct    = { label = i18n("snmp.cpuUser"),    color = timeseries_info.get_timeseries_color('default') },  system_pct = { label = i18n("snmp.cpuSystem"), color = timeseries_info.get_timeseries_color('default') },  idle_pct    = { label = i18n("snmp.cpuIdle"),    color = timeseries_info.get_timeseries_color('default') } }, default_visible = true },
  { schema = "snmp_dev:avail_memory",         id = timeseries_id.snmp, label =i18n("snmp.memAvailReal"),                 priority = 0, measure_unit = "number", scale = 0, timeseries = { avail_bytes = { label = i18n("snmp.memAvailReal"),    color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "snmp_dev:swap_memory",          id = timeseries_id.snmp, label =i18n("snmp.memTotalReal"),                 priority = 0, measure_unit = "number", scale = 0, timeseries = { swap_bytes  = { label = i18n("snmp.memTotalReal"),    color = timeseries_info.get_timeseries_color('default') } } },
  { schema = "snmp_dev:total_memory",         id = timeseries_id.snmp, label =i18n("snmp.memTotalSwap"),                 priority = 0, measure_unit = "number", scale = 0, timeseries = { total_bytes = { label = i18n("snmp.memTotalSwap"),    color = timeseries_info.get_timeseries_color('default') } } },
}

-- #################################

local function add_top_vlan_timeseries(tags, timeseries)
  local vlan_ts_enabled = ntop.getCache("ntopng.prefs.vlan_rrd_creation")
  
  ts_utils.loadSchemas()
  
  -- Top l7 Protocols
  if vlan_ts_enabled then
    local series = ts_utils.listSeries("vlan:ndpi", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series or {}) do
        timeseries[#timeseries + 1] = { schema = "top:vlan:ndpi", group = i18n("graphs.l7_proto"), priority = 2, query = "protocol:" .. serie.protocol , label = serie.protocol, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes') }, bytes_rcvd = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  return timeseries
end

-- #################################

local function add_top_host_pool_timeseries(tags, timeseries)
  local host_pool_ts_enabled = ntop.getCache("ntopng.prefs.host_pools_rrd_creation")
  
  ts_utils.loadSchemas()
  
  -- Top l7 Protocols
  if host_pool_ts_enabled then
    local series = ts_utils.listSeries("host_pool:ndpi", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series or {}) do
        timeseries[#timeseries + 1] = { schema = "top:host_pool:ndpi", group = i18n("graphs.l7_proto"), priority = 2, query = "protocol:" .. serie.protocol , label = serie.protocol, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes') }, bytes_rcvd = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  return timeseries
end

-- #################################

local function add_top_asn_timeseries(tags, timeseries)
  local asn_ts_enabled = ntop.getCache("ntopng.prefs.asn_rrd_creation")
  
  ts_utils.loadSchemas()
  
  -- Top l7 Protocols
  if asn_ts_enabled then
    local series = ts_utils.listSeries("asn:ndpi", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series or {}) do
        timeseries[#timeseries + 1] = { schema = "top:asn:ndpi", group = i18n("graphs.l7_proto"), priority = 2, query = "protocol:" .. serie.protocol , label = serie.protocol, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes') }, bytes_rcvd = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  return timeseries
end

-- #################################

local function add_top_mac_timeseries(tags, timeseries)
  local mac_ts_enabled = ntop.getCache("ntopng.prefs.l2_device_rrd_creation")
  local mac_top_ts_enabled = ntop.getCache("ntopng.prefs.l2_device_ndpi_timeseries_creation")
  
  ts_utils.loadSchemas()
  
  -- Top l7 Categories
  if mac_ts_enabled and mac_top_ts_enabled then
    local series = ts_utils.listSeries("mac:ndpi_categories", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series or {}) do
        local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
        timeseries[#timeseries + 1] = { schema = "top:mac:ndpi_categories", group = i18n("graphs.category"), priority = 3, query = "category:" .. category_name , label = category_name, measure_unit = "bps", scale = 0, timeseries = { bytes = { label = category_name, color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  return timeseries
end

-- #################################

local function add_top_host_timeseries(tags, timeseries)
  local host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
  local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
  local has_top_protocols = host_ts_enabled == "both" or host_ts_enabled == "per_protocol" or host_ts_enabled ~= "0"
  local has_top_categories = host_ts_enabled == "both" or host_ts_enabled == "per_category"

  ts_utils.loadSchemas()
  
  -- L4 Protocols
  if host_ts_creation == "full" then
    local series = ts_utils.listSeries("host:l4protos", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    if not table.empty(series) then
      for _, serie in pairs(series or {}) do
        timeseries[#timeseries + 1] = { schema = "top:host:ndpi", group = i18n("graphs.l4_proto"), priority = 2, query = "l4proto:" .. serie.l4proto , label = i18n(serie.l4proto) or serie.l4proto, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = serie.l4proto .. " " .. i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes') }, bytes_rcvd = { label = serie.l4proto .. " " .. i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  -- Top l7 Protocols
  if has_top_protocols then
    local series = ts_utils.listSeries("host:ndpi", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series or {}) do
        timeseries[#timeseries + 1] = { schema = "top:host:ndpi", group = i18n("graphs.l7_proto"), priority = 2, query = "protocol:" .. serie.protocol , label = serie.protocol, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes') }, bytes_rcvd = { label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  -- Top Categories
  if has_top_categories then
    local series = ts_utils.listSeries("host:ndpi_categories", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series) do
        local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
        timeseries[#timeseries + 1] = { schema = "top:host:ndpi_categories", group = i18n("graphs.category"), priority = 3, query = "category:" .. category_name , label = category_name, measure_unit = "bps", scale = 0, timeseries = { bytes = { label = category_name, color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end

  return timeseries
end

-- #################################

local function add_top_interface_timeseries(tags, timeseries)
  local interface_ts_enabled = ntop.getCache("ntopng.prefs.interface_ndpi_timeseries_creation")
  local has_top_protocols = interface_ts_enabled == "both" or interface_ts_enabled == "per_protocol" or interface_ts_enabled ~= "0"
  local has_top_categories = interface_ts_enabled == "both" or interface_ts_enabled == "per_category"

  ts_utils.loadSchemas()
  
  -- Top Traffic Profiles
  if ntop.isPro() then
    local series = ts_utils.listSeries("profile:traffic", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series) do
        timeseries[#timeseries + 1] = { schema = "top:profile:traffic", group = i18n("graphs.top_profiles"), priority = 2, query = "profile:" .. serie.profile , label = serie.profile, measure_unit = "bps", scale = 0, timeseries = { bytes = { label = serie.profile, color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end

  -- L4 Protocols
  if interface_ts_enabled then
    local series = ts_utils.listSeries("iface:l4protos", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series) do
        timeseries[#timeseries + 1] = { schema = "top:iface:l4protos", group = i18n("graphs.l4_proto"), priority = 2, query = "protocol:" .. serie.l4proto , label = i18n(serie.l4proto) or serie.l4proto, measure_unit = "bps", scale = 0, timeseries = { bytes = { label = serie.l4proto, color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end

  -- Top l7 Protocols
  if has_top_protocols then
    local series = ts_utils.listSeries("iface:ndpi", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series) do
        timeseries[#timeseries + 1] = { schema = "top:iface:ndpi", group = i18n("graphs.l7_proto"), priority = 2, query = "protocol:" .. serie.protocol , label = serie.protocol, measure_unit = "bps", scale = 0, timeseries = { bytes = { label = serie.protocol, color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end
  
  -- Top Categories
  if has_top_categories then
    local series = ts_utils.listSeries("iface:ndpi_categories", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series) do
        local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
        timeseries[#timeseries + 1] = { schema = "top:iface:ndpi_categories", group = i18n("graphs.category"), priority = 3, query = "category:" .. category_name , label = category_name, measure_unit = "bps", scale = 0, timeseries = { bytes = { label = category_name, color = timeseries_info.get_timeseries_color('bytes') }} }
      end
    end
  end

  return timeseries
end

-- #################################
local function add_top_timeseries(tags, prefix, timeseries)
  if prefix == 'iface' then
    -- Add the top interface timeseries
    timeseries = add_top_interface_timeseries(tags, timeseries)
  elseif prefix == 'host' then
    -- Add the top host timeseries
    timeseries = add_top_host_timeseries(tags, timeseries)
  elseif prefix == 'asn' then
    -- Add the top asn timeseries
    timeseries = add_top_asn_timeseries(tags, timeseries)
  elseif prefix == 'host_pool' then
    -- Add the top host pool timeseries
    timeseries = add_top_host_pool_timeseries(tags, timeseries)
  elseif prefix == 'vlan' then
    -- Add the top vlan timeseries
    timeseries = add_top_vlan_timeseries(tags, timeseries)
  elseif prefix == 'mac' then
    -- Add the top vlan timeseries
    timeseries = add_top_mac_timeseries(tags, timeseries)
  end

  return timeseries
end

-- #################################

function timeseries_info.retrieve_specific_timeseries(tags, prefix)
  local timeseries_list = community_timeseries
  local timeseries = {}

  if ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
    local timeseries_info_ext = require "timeseries_info_ext"
    local pro_timeseries = timeseries_info_ext.retrieve_pro_timeseries(prefix)
    timeseries_list = table.merge(community_timeseries, pro_timeseries)
  end

  for _, info in pairs(timeseries_list) do
    -- Check if the schema starts with 'iface:', 
    -- if not then it's not an interface timeseries, so drop it
    if info.id ~= prefix then
      goto skip
    end

    -- Remove from nEdge the timeseries only for ntopng
    if (info.nedge_exclude) and (ntop.isnEdge()) then
      goto skip
    end

    -- Remove from ntopng the timeseries only for nEdge
    if (info.nedge_only) and (not ntop.isnEdge()) then
      goto skip
    end

    timeseries[#timeseries + 1] = info

    ::skip::
  end
  
  timeseries = add_top_timeseries(tags, prefix, timeseries)

  return timeseries  
end

-- #################################

function timeseries_info.get_host_rules_schema()
  local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
  local has_top_protocols = host_ts_enabled == "both" or host_ts_enabled == "per_protocol" or host_ts_enabled ~= "0"
  local has_top_categories = host_ts_enabled == "both" or host_ts_enabled == "per_category"

  local metric_list = {
    { title = i18n('traffic'), group = i18n('generic_data'), label = i18n('traffic'), id = 'host:traffic' --[[ here the ID is the schema ]] },
    { title = i18n('score'),  group = i18n('generic_data'), label = i18n('score'), id = 'host:score' --[[ here the ID is the schema ]] },
  } 

  if has_top_protocols then
    local application_list = interface.getnDPIProtocols()
    for application, _ in pairsByKeys(application_list or {}, asc) do 
      metric_list[#metric_list + 1] = { label = application, group = i18n('applications_long'), title = application, id = 'top:host:ndpi,protocol:' .. application --[[ here the schema is the ID ]] }
    end
  end

  if has_top_categories then
    local category_list = interface.getnDPICategories()
    for category, _ in pairsByKeys(category_list or {}, asc) do 
      metric_list[#metric_list + 1] = { label = category, group = i18n('categories'), title = category, id = 'top:host:ndpi_categories,category:' .. category --[[ here the schema is the ID ]] }
    end
  end

  return metric_list
end

-- #################################

return timeseries_info
