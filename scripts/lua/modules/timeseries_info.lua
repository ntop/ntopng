--
-- (C) 2014-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local timeseries_utils = {}

-- #################################

local series_extra_info = {
  alerts = {
    color = 'black'
  },
  bytes = {
    color = 'yellow'
  },
  bytes_sent = {
    color = 'blu'
  },
  bytes_rcvd = {
    color = 'green'
  },
  devices = {
    color = 'orange'
  },
  flows = {
    color = 'purple'
  },
  hosts = {
    color = 'red'
  },
  score = {
    color = 'red'
  },
  cli_score = {
    color = 'orange'
  },
  srv_score = {
    color = 'yellow'
  },
  default = {
    color = 'grey'
  }
}

-- #################################

function timeseries_utils.get_timeseries_color(subject)
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
  { schema = "iface:flows",                   label = i18n("graphs.active_flows"),              measure_unit = "number", scale = 0, timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_utils.get_timeseries_color('flows') }}},
  { schema = "iface:new_flows",               label = i18n("graphs.new_flows"),                 measure_unit = "fps",    scale = 0, timeseries = { new_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_utils.get_timeseries_color('flows') }}},
  { schema = "iface:alerted_flows",           label = i18n("graphs.total_alerted_flows"),       measure_unit = "number", scale = 0, timeseries = { num_flows          = { label = i18n('graphs.metric_labels.num_flows'),   color = timeseries_utils.get_timeseries_color('flows') }}},
  { schema = "iface:hosts",                   label = i18n("graphs.active_hosts"),              measure_unit = "number", scale = 0, timeseries = { num_hosts          = { label = i18n('graphs.metric_labels.num_hosts'),   color = timeseries_utils.get_timeseries_color('hosts') }}},
  { schema = "iface:engaged_alerts",          label = i18n("show_alerts.engaged_alerts"),       measure_unit = "number", scale = 0, timeseries = { engaged_alerts     = { label = i18n('show_alerts.engaged_alerts'),       color = timeseries_utils.get_timeseries_color('alerts') }}},
  { schema = "iface:dropped_alerts",          label = i18n("show_alerts.dropped_alerts"),       measure_unit = "number", scale = 0, timeseries = { dropped_alerts     = { label = i18n('show_alerts.dropped_alerts'),       color = timeseries_utils.get_timeseries_color('alerts') }}},
  { schema = "iface:devices",                 label = i18n("graphs.active_devices"),            measure_unit = "number", scale = 0, timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_devices'), color = timeseries_utils.get_timeseries_color('devices') }}},
  { schema = "iface:http_hosts",              label = i18n("graphs.active_http_servers"),       measure_unit = "number", scale = 0, timeseries = { num_devices        = { label = i18n('graphs.metric_labels.num_servers'), color = timeseries_utils.get_timeseries_color('devices') }}, nedge_exclude = true },
  { schema = "iface:traffic",                 label = i18n("traffic"),                          measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.traffic'),     color = timeseries_utils.get_timeseries_color('devices') }}, nedge_exclude = true },
  { schema = "iface:score",                   label = i18n("score"),                            measure_unit = "number", scale = 0, timeseries = { cli_score          = { label = i18n('graphs.cli_score'),                 color = timeseries_utils.get_timeseries_color('cli_score') }, srv_score = { label = i18n('graphs.srv_score'), color = timeseries_utils.get_timeseries_color('srv_score') }}},
  { schema = "iface:traffic_rxtx",            label = i18n("graphs.traffic_rxtx"),              measure_unit = "bps",    scale = 0, timeseries = { bytes_sent         = { label = i18n('graphs.metric_labels.sent'),        color = timeseries_utils.get_timeseries_color('bytes_sent') }, bytes_rcvd = { invert_direction = true, label = i18n('graphs.metric_labels.rcvd'), color = timeseries_utils.get_timeseries_color('bytes_rcvd') }}},
  { schema = "iface:packets_vs_drops",        label = i18n("graphs.packets_vs_drops"),          measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.metric_labels.packets'),     color = timeseries_utils.get_timeseries_color('packets') }, drops = { label = i18n('graphs.metric_labels.drops'), color = timeseries_utils.get_timeseries_color('default') }}},
  { schema = "iface:nfq_pct",                 label = i18n("graphs.num_nfq_pct"),               measure_unit = "number", scale = 0, timeseries = { num_nfq_pct        = { label = i18n('graphs.num_nfq_pct'),               color = timeseries_utils.get_timeseries_color('default') }}, nedge_only = true },
  { schema = "iface:hosts_anomalies",         label = i18n("graphs.hosts_anomalies"),           measure_unit = "number", scale = 0, timeseries = { num_loc_hosts_anom = { label = i18n('graphs.loc_host_anomalies'),        color = timeseries_utils.get_timeseries_color('hosts') }, num_rem_hosts_anom = { label = i18n('graphs.rem_host_anomalies'), color = timeseries_utils.get_timeseries_color('hosts') }}},
  { schema = "iface:disc_prob_bytes",         label = i18n("graphs.discarded_probing_bytes"),   measure_unit = "bps",    scale = 0, timeseries = { bytes              = { label = i18n('graphs.metric_labels.bytes'),       color = timeseries_utils.get_timeseries_color('bytes') }}, nedge_exclude = true },
  { schema = "iface:disc_prob_pkts",          label = i18n("graphs.discarded_probing_packets"), measure_unit = "pps",    scale = 0, timeseries = { packets            = { label = i18n('graphs.metric_labels.packets'),     color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:dumped_flows",            label = i18n("graphs.dumped_flows"),              measure_unit = "pps",    scale = 0, timeseries = { dumped_flows       = { label = i18n('graphs.dumped_flows'),              color = timeseries_utils.get_timeseries_color('flows') }, dropped_flows = { label = i18n('graphs.dumped_flows'), color = timeseries_utils.get_timeseries_color('flows') }}},
  { schema = "iface:zmq_recv_flows",          label = i18n("graphs.zmq_received_flows"),        measure_unit = "number", scale = 0, timeseries = { flows              = { label = i18n('graphs.zmq_received_flows'),        color = timeseries_utils.get_timeseries_color('flows') }}},
  { schema = "iface:zmq_flow_coll_drops",     label = i18n("graphs.zmq_flow_coll_drops"),       measure_unit = "number", scale = 0, timeseries = { drops              = { label = i18n('graphs.zmq_flow_coll_drops'),       color = timeseries_utils.get_timeseries_color('default') }}, nedge_exclude = true },
  { schema = "iface:zmq_flow_coll_udp_drops", label = i18n("graphs.zmq_flow_coll_udp_drops"),   measure_unit = "number", scale = 0, timeseries = { drops              = { label = i18n('graphs.zmq_flow_coll_udp_drops'),   color = timeseries_utils.get_timeseries_color('default') }}, nedge_exclude = true },
  { schema = "iface:tcp_lost",                label = i18n("graphs.tcp_packets_lost"),          measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_packets_lost'),          color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_out_of_order",        label = i18n("graphs.tcp_packets_ooo"),           measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_packets_ooo'),           color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_retransmissions",     label = i18n("graphs.tcp_packets_retr"),          measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_packets_retr'),          color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_keep_alive",          label = i18n("graphs.tcp_packets_keep_alive"),    measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_packets_keep_alive'),    color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_syn",                 label = i18n("graphs.tcp_syn_packets"),           measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_syn_packets'),           color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_synack",              label = i18n("graphs.tcp_synack_packets"),        measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_syn_packets'),           color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_finack",              label = i18n("graphs.tcp_finack_packets"),        measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_finack_packets'),        color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
  { schema = "iface:tcp_rst",                 label = i18n("graphs.tcp_rst_packets"),           measure_unit = "number", scale = 0, timeseries = { packets            = { label = i18n('graphs.tcp_rst_packets'),           color = timeseries_utils.get_timeseries_color('packets') }}, nedge_exclude = true },
}

local pro_timeseries = {
  { schema = "iface:score_anomalies",         label = i18n("graphs.iface_score_anomalies"),     measure_unit = "number", scale = 0, timeseries = { anomaly            = { label = i18n('graphs.iface_score_anomalies'),     color = timeseries_utils.get_timeseries_color('default') }}, nedge_exclude = true },
  { schema = "iface:traffic_anomalies",       label = i18n("graphs.iface_traffic_anomalies"),   measure_unit = "number", scale = 0, timeseries = { anomaly            = { label = i18n('graphs.iface_traffic_anomalies'),   color = timeseries_utils.get_timeseries_color('default') }}, nedge_exclude = true },
  { schema = "iface:score_behavior",          label = i18n("graphs.iface_score_behavior"),      measure_unit = "number", scale = 0, timeseries = { value              = { label = i18n('graphs.score'),                     color = timeseries_utils.get_timeseries_color('score') }, lower_bound = { label = i18n('graphs.lower_bound'), color = timeseries_utils.get_timeseries_color('score') }, upper_bound = { label = i18n('graphs.upper_bound'), color = timeseries_utils.get_timeseries_color('score') }}, nedge_exclude = true },
  { schema = "iface:local_hosts",             label = i18n("graphs.iface_active_local_hosts"),  measure_unit = "number", scale = 0, timeseries = { num_hosts          = { label = i18n('graphs.metrics_prefixes.num_hosts'),color = timeseries_utils.get_timeseries_color('default') }}, nedge_exclude = true },
  { schema = "iface:traffic_rx_behavior_v2",  label = i18n("graphs.iface_traffic_rx_behavior"), measure_unit = "bps",    scale = 0, timeseries = { value              = { label = i18n('graphs.traffic_rcvd'),              color = timeseries_utils.get_timeseries_color('bytes') }, lower_bound = { label = i18n('graphs.lower_bound'), color = timeseries_utils.get_timeseries_color('bytes') }, upper_bound = { label = i18n('graphs.upper_bound'), color = timeseries_utils.get_timeseries_color('bytes') }}, nedge_exclude = true },
  { schema = "iface:traffic_tx_behavior_v2",  label = i18n("graphs.iface_traffic_tx_behavior"), measure_unit = "bps",    scale = 0, timeseries = { value              = { label = i18n('graphs.traffic_sent'),              color = timeseries_utils.get_timeseries_color('bytes') }, lower_bound = { label = i18n('graphs.lower_bound'), color = timeseries_utils.get_timeseries_color('bytes') }, upper_bound = { label = i18n('graphs.upper_bound'), color = timeseries_utils.get_timeseries_color('bytes') }}, nedge_exclude = true },
  { schema = "iface:score_behavior",          label = i18n("graphs.iface_score_behavior"),      measure_unit = "number", scale = 0, timeseries = { value              = { label = i18n('graphs.score'),                     color = timeseries_utils.get_timeseries_color('score') }, lower_bound = { label = i18n('graphs.lower_bound'), color = timeseries_utils.get_timeseries_color('score') }, upper_bound = { label = i18n('graphs.upper_bound'), color = timeseries_utils.get_timeseries_color('score') }}, nedge_exclude = true },
  { schema = "iface:behavioural_maps",        label = i18n("graphs.behavioural_maps"),          measure_unit = "number", scale = 0, timeseries = { period_map_entries = { label = i18n('graphs.periodicity_map_entries'),   color = timeseries_utils.get_timeseries_color('default') }, svc_map_entries = { label = i18n('graphs.service_map_entries'), color = timeseries_utils.get_timeseries_color('default') }}, nedge_exclude = true },
}

-- #################################

function timeseries_utils.get_interface_timeseries()
  local timeseries_list = community_timeseries
  if ntop.isPro() then
    timeseries_list = table.merge(community_timeseries, pro_timeseries)
  end

  for index, info in pairs(timeseries_list) do
    -- Check if the schema starts with 'iface:', 
    -- if not then it's not an interface timeseries, so drop it
    if not string.starts(info.schema, 'iface:') then
      table.remove(timeseries_list, index)
    end
  end

  return timeseries_list
end

-- #################################

return timeseries_utils
