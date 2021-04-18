--
-- (C) 2013-21 - ntop.org
--

local hosts_map_utils = {}

-- Simple Lua "enumerator" to improve code readability
hosts_map_utils.HostsMapMode = {
    ALL_FLOWS = 0,
    UNREACHABLE_FLOWS  = 1,
    ALERTED_FLOWS = 2,
    DNS_QUERIES = 3,
    DNS_BYTES = 4,
    NTP_PACKETS = 5,
    SYN_DISTRIBUTION = 6,
    SYN_VS_RST = 7,
    SYN_VS_SYNACK = 8,
    TCP_PKTS_SENT_VS_RCVD = 9,
    TCP_BYTES_SENT_VS_RCVD = 10,
    ACTIVE_ALERT_FLOWS = 11,
    TRAFFIC_RATIO = 12,
    SCORE = 13,
    BLACKLISTED_FLOWS_HOSTS = 14,
}

hosts_map_utils.MODES = {
   {
        mode = hosts_map_utils.HostsMapMode.ALL_FLOWS,
        label   = i18n("hosts_map_page.all_flows"),
        x_label = i18n("hosts_map_page.labels.f_s"),
        y_label = i18n("hosts_map_page.labels.f_c")
    }, {
        mode = hosts_map_utils.HostsMapMode.UNREACHABLE_FLOWS,
        label   = i18n("hosts_map_page.unreach_flows"),
        x_label = i18n("hosts_map_page.labels.uf_s"),
        y_label = i18n("hosts_map_page.labels.uf_c")
    }, {
        mode = hosts_map_utils.HostsMapMode.ALERTED_FLOWS,
        label   = i18n("hosts_map_page.alerted_flows"),
        x_label = i18n("hosts_map_page.labels.af_s"),
        y_label = i18n("hosts_map_page.labels.af_c")
    }, {
        mode = hosts_map_utils.HostsMapMode.DNS_QUERIES,
        label   = i18n("hosts_map_page.dns_queries"),
        x_label = i18n("hosts_map_page.labels.dns_p_r"),
        y_label = i18n("hosts_map_page.labels.dns_s")
    }, {
        mode = hosts_map_utils.HostsMapMode.DNS_BYTES,
        label   = i18n("hosts_map_page.dns_bytes"),
        x_label = i18n("hosts_map_page.labels.dns_r"),
	y_label = i18n("hosts_map_page.labels.dns_sent"),
        x_formatter = "bytesToSize",
        y_formatter = "bytesToSize",
	pro = true,
	visible = interface.trafficMapEnabled,
    }, {
        mode = hosts_map_utils.HostsMapMode.NTP_PACKETS,
        label   = i18n("hosts_map_page.ntp_packets"),
	x_label = i18n("hosts_map_page.labels.ntp_r"),
        y_label = i18n("hosts_map_page.labels.ntp_s"),
	pro = true,
	visible = interface.trafficMapEnabled,
    }, {
        mode = hosts_map_utils.HostsMapMode.SYN_DISTRIBUTION,
        label   = i18n("hosts_map_page.syn_distribution"),
        x_label = i18n("hosts_map_page.labels.syn_s"),
        y_label = i18n("hosts_map_page.labels.syn_r")
    }, {
        mode = hosts_map_utils.HostsMapMode.SYN_VS_RST,
        label   = i18n("hosts_map_page.syn_vs_rst"),
        x_label = i18n("hosts_map_page.labels.syn_s"),
        y_label = i18n("hosts_map_page.labels.rst_r")
    }, {
        mode = hosts_map_utils.HostsMapMode.SYN_VS_SYNACK,
        label   = i18n("hosts_map_page.syn_vs_synack"),
        x_label = i18n("hosts_map_page.labels.syn_s"),
        y_label = i18n("hosts_map_page.labels.sa_r")
    }, {
        mode = hosts_map_utils.HostsMapMode.TCP_PKTS_SENT_VS_RCVD,
        label   = i18n("hosts_map_page.tcp_pkts_sent_vs_rcvd"),
        x_label = i18n("hosts_map_page.labels.tcp_p_s"),
        y_label = i18n("hosts_map_page.labels.tcp_p_r")
    }, {
        mode = hosts_map_utils.HostsMapMode.TCP_BYTES_SENT_VS_RCVD,
        label   = i18n("hosts_map_page.tcp_bytes_sent_vs_rcvd"),
        x_label = i18n("hosts_map_page.labels.tcp_b_s"),
        y_label = i18n("hosts_map_page.labels.tcp_b_r"),
        x_formatter = "bytesToSize",
        y_formatter = "bytesToSize",
    }, {
        mode = hosts_map_utils.HostsMapMode.ACTIVE_ALERT_FLOWS,
        label   = i18n("hosts_map_page.active_alert_flows"),
        x_label = i18n("hosts_map_page.labels.f_a_s"),
        y_label = i18n("hosts_map_page.labels.f_a_c")
    }, {
        mode = hosts_map_utils.HostsMapMode.TRAFFIC_RATIO,
        label   = i18n("hosts_map_page.traffic_ratio"),
        x_label = i18n("hosts_map_page.labels.b_ratio"),
        y_label = i18n("hosts_map_page.labels.p_ratio"),
        y_formatter = "toFixed2"
    }, {
        mode = hosts_map_utils.HostsMapMode.SCORE,
        label   = i18n("hosts_map_page.score"),
        x_label = i18n("hosts_map_page.labels.client_score"),
        y_label = i18n("hosts_map_page.labels.server_score")
    }, {
        mode = hosts_map_utils.HostsMapMode.BLACKLISTED_FLOWS_HOSTS,
        label   = i18n("hosts_map_page.blacklisted_flows_hosts"),
        x_label = i18n("hosts_map_page.labels.blacklisted_as_client"),
        y_label = i18n("hosts_map_page.labels.blacklisted_as_server")
    }
}

return hosts_map_utils
