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
  { schema = "iface:traffic_rxtx",            label = i18n("graphs.traffic_rxtx"),              priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "iface:flows",                   label = i18n("graphs.active_flows"),              priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:new_flows",               label = i18n("graphs.new_flows"),                 priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { new_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:alerted_flows",           label = i18n("graphs.total_alerted_flows"),       priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:hosts",                   label = i18n("graphs.active_hosts"),              priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.hosts'), timeseries = { num_hosts          = { label = i18n('graphs.metric_labels.num_hosts'),   color = timeseries_info.get_timeseries_color('hosts') }}},
  { schema = "iface:engaged_alerts",          label = i18n("graphs.engaged_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { engaged_alerts     = { label = i18n('graphs.engaged_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},
  { schema = "iface:dropped_alerts",          label = i18n("graphs.dropped_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { dropped_alerts     = { label = i18n('graphs.dropped_alerts'),            color = timeseries_info.get_timeseries_color('alerts') }}},
  { schema = "iface:devices",                 label = i18n("graphs.active_devices"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.devices'), timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_devices'), color = timeseries_info.get_timeseries_color('devices') }}},
  { schema = "iface:http_hosts",              label = i18n("graphs.active_http_servers"),       priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.servers'), timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_servers'), color = timeseries_info.get_timeseries_color('devices') }},  nedge_exclude = true },
  { schema = "iface:traffic",                 label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.traffic'),     color = timeseries_info.get_timeseries_color('devices') }},  nedge_exclude = true },
  { schema = "iface:score",                   label = i18n("graphs.score"),                     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.score'), timeseries = { cli_score          = { label = i18n('graphs.cli_score'),                 color = timeseries_info.get_timeseries_color('cli_score') },   srv_score = { label = i18n('graphs.srv_score'), color = timeseries_info.get_timeseries_color('srv_score') }}},
  { schema = "iface:packets_vs_drops",        label = i18n("graphs.packets_vs_drops"),          priority = 0, measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.metric_labels.packets'),     color = timeseries_info.get_timeseries_color('packets') },     drops = { label = i18n('graphs.metric_labels.drops'), draw_type = "line", color = timeseries_info.get_timeseries_color('default') }}},
  { schema = "iface:nfq_pct",                 label = i18n("graphs.num_nfq_pct"),               priority = 0, measure_unit = "percentage", scale = 0, timeseries = { num_nfq_pct        = { label = i18n('graphs.num_nfq_pct'),               color = timeseries_info.get_timeseries_color('default') }},  nedge_only = true },
  { schema = "iface:hosts_anomalies",         label = i18n("graphs.hosts_anomalies"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.anomalies'), timeseries = { num_loc_hosts_anom = { label = i18n('graphs.loc_host_anomalies'),        color = timeseries_info.get_timeseries_color('hosts') },       num_rem_hosts_anom = { label = i18n('graphs.rem_host_anomalies'), draw_type = "line", color = timeseries_info.get_timeseries_color('hosts') }}},
  { schema = "iface:disc_prob_bytes",         label = i18n("graphs.discarded_probing_bytes"),   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.drops'),       color = timeseries_info.get_timeseries_color('bytes') }},    nedge_exclude = true },
  { schema = "iface:disc_prob_pkts",          label = i18n("graphs.discarded_probing_packets"), priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets            = { label = i18n('graphs.metric_labels.drops'),       color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:dumped_flows",            label = i18n("graphs.dumped_flows"),              priority = 0, measure_unit = "fps",    scale = 0, timeseries = { dumped_flows       = { label = i18n('graphs.dumped_flows'),              color = timeseries_info.get_timeseries_color('flows') },       dropped_flows = { label = i18n('graphs.dumped_flows'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:zmq_recv_flows",          label = i18n("graphs.zmq_received_flows"),        priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { flows              = { label = i18n('graphs.zmq_received_flows'),        color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "iface:zmq_flow_coll_drops",     label = i18n("graphs.zmq_flow_coll_drops"),       priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { drops              = { label = i18n('graphs.zmq_flow_coll_drops'),       color = timeseries_info.get_timeseries_color('default') }},  nedge_exclude = true },
  { schema = "iface:zmq_flow_coll_udp_drops", label = i18n("graphs.zmq_flow_coll_udp_drops"),   priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.flows'), timeseries = { drops              = { label = i18n('graphs.zmq_flow_coll_udp_drops'),   color = timeseries_info.get_timeseries_color('default') }},  nedge_exclude = true },
  { schema = "iface:tcp_lost",                label = i18n("graphs.tcp_packets_lost"),          priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_lost'),          color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_out_of_order",        label = i18n("graphs.tcp_packets_ooo"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_ooo'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_retransmissions",     label = i18n("graphs.tcp_packets_retr"),          priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_retr'),          color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_keep_alive",          label = i18n("graphs.tcp_packets_keep_alive"),    priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_packets_keep_alive'),    color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_syn",                 label = i18n("graphs.tcp_syn_packets"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_syn_packets'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_synack",              label = i18n("graphs.tcp_synack_packets"),        priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_syn_packets'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_finack",              label = i18n("graphs.tcp_finack_packets"),        priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_finack_packets'),        color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "iface:tcp_rst",                 label = i18n("graphs.tcp_rst_packets"),           priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.packets'), timeseries = { packets            = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_info.get_timeseries_color('packets') }},  nedge_exclude = true },
  { schema = "host:traffic",                  label = i18n("graphs.traffic"),                   priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes_sent') },  bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },
  { schema = "host:score",                    label = i18n("graphs.score"),                     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.score'), timeseries = { cli_score          = { label = i18n('graphs.cli_score'),                 color = timeseries_info.get_timeseries_color('cli_score') },   srv_score = { label = i18n('graphs.srv_score'), color = timeseries_info.get_timeseries_color('srv_score') }}},
  { schema = "host:active_flows",             label = i18n("graphs.active_flows"),              priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:total_flows",              label = i18n("graphs.total_flows"),               priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:num_blacklisted_flows",    label = i18n("graphs.num_blacklisted_flows"),     priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:alerted_flows",            label = i18n("graphs.total_alerted_flows"),       priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:unreachable_flows",        label = i18n("graphs.total_unreachable_flows"),   priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:host_unreachable_flows",   label = i18n("graphs.host_unreachable_flows"),    priority = 0, measure_unit = "fps",    scale = 0, timeseries = { flows_as_client    = { label = i18n('graphs.flows_as_client'),           color = timeseries_info.get_timeseries_color('flows') },       flows_as_server = { label = i18n('graphs.flows_as_server'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:contacts",                 label = i18n("graphs.active_host_contacts"),      priority = 0, measure_unit = "fps",    scale = 0, timeseries = { num_as_clients     = { label = i18n('graphs.metric_labels.as_cli'),      color = timeseries_info.get_timeseries_color('flows') },       num_as_server   = { label = i18n('graphs.metric_labels.as_srv'), color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "host:contacts_behaviour",       label = i18n("graphs.host_contacts_behaviour"),   priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.contacts'), timeseries = { value              = { label = i18n('graphs.score'),                     color = timeseries_info.get_timeseries_color('score') },       lower_bound     = { label = i18n('graphs.lower_bound'), draw_type = "line", color = timeseries_info.get_timeseries_color('score') }, upper_bound = { label = i18n('graphs.upper_bound'), draw_type = "line", color = timeseries_info.get_timeseries_color('score') }}, nedge_exclude = true },
  { schema = "host:total_alerts",             label = i18n("graphs.alerts"),                    priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { alerts             = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:engaged_alerts",           label = i18n("graphs.engaged_alerts"),            priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.alerts'), timeseries = { alerts             = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:dns_qry_sent_rsp_rcvd",    label = i18n("graphs.dns_qry_sent_rsp_rcvd"),     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.queries'), timeseries = { queries_pkts       = { label = i18n('graphs.metric_labels.queries_pkts'),color = timeseries_info.get_timeseries_color('default') },     replies_ok_pkts = { label = i18n('graphs.metric_labels.ok_pkts'), color = timeseries_info.get_timeseries_color('default') }, replies_error_pkts = { label = i18n('graphs.metric_labels.error_pkts'), color = timeseries_info.get_timeseries_color('default') }}},
  { schema = "host:dns_qry_rcvd_rsp_sent",    label = i18n("graphs.dns_qry_rcvd_rsp_sent"),     priority = 0, measure_unit = "number", scale = i18n('graphs.metric_labels.queries'), timeseries = { queries_pkts       = { label = i18n('graphs.metric_labels.queries_pkts'),color = timeseries_info.get_timeseries_color('default') },     replies_ok_pkts = { label = i18n('graphs.metric_labels.ok_pkts'), color = timeseries_info.get_timeseries_color('default') }, replies_error_pkts = { label = i18n('graphs.metric_labels.error_pkts'), color = timeseries_info.get_timeseries_color('default') }}},
  { schema = "host:tcp_rx_stats",             label = i18n("graphs.tcp_rx_stats"),              priority = 0, measure_unit = "pps",    scale = 0, timeseries = { retran_pkts        = { label = i18n('graphs.metric_labels.retra_pkts'),  color = timeseries_info.get_timeseries_color('packets') },     out_of_order_pkts = { label = i18n('graphs.metric_labels.ooo_pkts'), color = timeseries_info.get_timeseries_color('packets') }, lost_packets = { label = i18n('graphs.metric_labels.lost_pkts'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:tcp_tx_stats",             label = i18n("graphs.tcp_tx_stats"),              priority = 0, measure_unit = "pps",    scale = 0, timeseries = { retran_pkts        = { label = i18n('graphs.metric_labels.retra_pkts'),  color = timeseries_info.get_timeseries_color('packets') },     out_of_order_pkts = { label = i18n('graphs.metric_labels.ooo_pkts'), color = timeseries_info.get_timeseries_color('packets') }, lost_packets = { label = i18n('graphs.metric_labels.lost_pkts'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:udp_pkts",                 label = i18n("graphs.udp_packets"),               priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:echo_reply_packets",       label = i18n("graphs.echo_reply_packets"),        priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:echo_packets",             label = i18n("graphs.echo_request_packets"),      priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:tcp_packets",              label = i18n("graphs.tcp_packets"),               priority = 0, measure_unit = "pps",    scale = 0, timeseries = { packets_sent       = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('packets') },     packets_rcvd    = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('packets') }}},
  { schema = "host:udp_sent_unicast",         label = i18n("graphs.udp_sent_unicast_vs_non_unicast"), priority = 0, measure_unit = "bps", scale = 0, timeseries = { bytes_sent_unicast = { label = i18n('graphs.metric_labels.sent_uni'), color = timeseries_info.get_timeseries_color('bytes') },       bytes_sent_non_uni = { label = i18n('graphs.metric_labels.sent_non_uni'), color = timeseries_info.get_timeseries_color('bytes') }}},
  { schema = "host:dscp",                     label = i18n("graphs.dscp_classes"),              priority = 0, measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_info.get_timeseries_color('bytes') },       bytes_rcvd      = { label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes') }}},
  { schema = "host:host_tcp_unidirectional_flows", label = i18n("graphs.unidirectional_tcp_flows"), priority = 0, measure_unit = "fps",scale = 0, timeseries = { flows_as_client         = { label = i18n('graphs.flows_as_client'),      color = timeseries_info.get_timeseries_color('flows') },  flows_as_server      = { label = i18n('graphs.flows_as_server'),    color = timeseries_info.get_timeseries_color('flows') }}},
  { schema = "mac:traffic", label = i18n("traffic"), priority = 0, measure_unit = "bps", scale = 0, timeseries = { bytes_sent = { label = i18n('graphs.metric_labels.sent'), color = timeseries_info.get_timeseries_color('bytes_sent') }, bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_info.get_timeseries_color('bytes_rcvd') }}, default_visible = true },

  -- network_details.lua (SUBNET): --
  { schema = "subnet:traffic", label = i18n("traffic"), measure_unit = "bps", scale = 0, timeseries = { bytes_egress = { label = i18n('graphs.metrics_suffixes.egress') }, bytes_ingress = { label = i18n('graphs.metrics_suffixes.ingress') }, bytes_inner = { label = i18n('graphs.metrics_suffixes.inner') }}, default_visible = true },
  { schema = "subnet:broadcast_traffic", label = i18n("broadcast_traffic"), measure_unit = "bps", scale = 0, timeseries = { bytes_egress = { label = i18n('graphs.metrics_suffixes.egress') }, bytes_ingress = { label = i18n('graphs.metrics_suffixes.ingress') }, bytes_inner = { label = i18n('graphs.metrics_suffixes.inner') }} },
  { schema = "subnet:engaged_alerts", label = i18n("show_alerts.engaged_alerts"), measure_unit = "number", scale = 0, timeseries = { alerts = { label = i18n('graphs.engaged_alerts') }} },
  { schema = "subnet:score", label = i18n("score"), measure_unit = "number", scale = 0, timeseries = { score = { label = i18n('score') }, scoreAsClient = { label = i18n('score_as_client') }, scoreAsServer = { label = i18n('score_as_server') } }},
  { schema = "subnet:tcp_retransmissions", label = i18n("graphs.tcp_packets_retr"), measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
    { schema = "subnet:tcp_out_of_order", label = i18n("graphs.tcp_packets_ooo"), measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
    { schema = "subnet:tcp_lost", label = i18n("graphs.tcp_packets_lost"), measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
    { schema = "subnet:tcp_keep_alive", label = i18n("graphs.tcp_packets_keep_alive"), measure_unit = "number", scale = 0, timeseries = { packets_ingress = { label = i18n('if_stats_overview.ingress_packets') }, packets_egress = { label = i18n('if_stats_overview.egress_packets') }, packets_inner = { label = 'Inner Packets' } }},
  
}

-- #################################

local function add_top_host_timeseries(tags, timeseries)
  local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
  local has_top_protocols = host_ts_enabled == "both" or host_ts_enabled == "per_protocol" or host_ts_enabled ~= "0"
  local has_top_categories = host_ts_enabled == "both" or host_ts_enabled == "per_category"

  ts_utils.loadSchemas()
  
  -- Top l7 Protocols
  if has_top_protocols then
    local series = ts_utils.listSeries("host:ndpi", table.clone(tags), os.time() - 1800 --[[ 30 min is the default time ]])
    
    if not table.empty(series) then
      for _, serie in pairs(series) do
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
    if not string.starts(info.schema, prefix) then
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

function timeseries_info.get_interface_timeseries(tags)
  return timeseries_info.retrieve_specific_timeseries(tags, 'iface')
end

-- #################################

function timeseries_info.get_host_timeseries(tags)
  return timeseries_info.retrieve_specific_timeseries(tags, 'host')
end

-- #################################

function timeseries_info.get_mac_timeseries(tags)
  return timeseries_info.retrieve_specific_timeseries(tags, 'mac')
end

-- #################################

return timeseries_info
