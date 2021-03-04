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
    SYN_DISTRIBUTION = 4,
    SYN_VS_RST = 5,
    SYN_VS_SYNACK = 6,
    TCP_PKTS_SENT_VS_RCVD = 7,
    TCP_BYTES_SENT_VS_RCVD = 8,
    ACTIVE_ALERT_FLOWS = 9
}

hosts_map_utils.MODES = {
    {
        mode = hosts_map_utils.HostsMapMode.ALL_FLOWS,
        label = i18n("hosts_map_page.all_flows"),
        x_label = "Flows as Server",
        y_label = "Flows as Client"
    }, {
        mode = hosts_map_utils.HostsMapMode.UNREACHABLE_FLOWS,
        label = i18n("hosts_map_page.unreach_flows"),
        x_label = "Unreachable Flows as Server",
        y_label = "Unreachable Flows as Client"
    }, {
        mode = hosts_map_utils.HostsMapMode.ALERTED_FLOWS,
        label = i18n("hosts_map_page.alerted_flows"),
        x_label = "Alerted Flows as Server",
        y_label = "Alerted Flows as Client"
    }, {
        mode = hosts_map_utils.HostsMapMode.DNS_QUERIES,
        label = i18n("hosts_map_page.dns_queries"),
        x_label = "Positive DNS Replies Received",
        y_label = "DNS Queries Sent"
    }, {
        mode = hosts_map_utils.HostsMapMode.SYN_DISTRIBUTION,
        label = i18n("hosts_map_page.syn_distribution"),
        x_label = "# of SYN Sent",
        y_label = "# of SYN Received"
    }, {
        mode = hosts_map_utils.HostsMapMode.SYN_VS_RST,
        label = i18n("hosts_map_page.syn_vs_rst"),
        x_label = "# of SYN Sent",
        y_label = "# of SYN Received"
    }, {
        mode = hosts_map_utils.HostsMapMode.SYN_VS_SYNACK,
        label = i18n("hosts_map_page.syn_vs_synack"),
        x_label = "# of SYN Sent",
        y_label = "# of SYN Received"
    }, {
        mode = hosts_map_utils.HostsMapMode.TCP_PKTS_SENT_VS_RCVD,
        label = i18n("hosts_map_page.tcp_pkts_sent_vs_rcvd"),
        x_label = "TCP Packets Sent",
        y_label = "TCP Packets Received"
    }, {
        mode = hosts_map_utils.HostsMapMode.TCP_BYTES_SENT_VS_RCVD,
        label = i18n("hosts_map_page.tcp_bytes_sent_vs_rcvd"),
        x_label = "TCP Bytes Sent",
        y_label = "TCP Bytes Received"
    }, {
        mode = hosts_map_utils.HostsMapMode.ACTIVE_ALERT_FLOWS,
        label = i18n("hosts_map_page.active_alert_flows"),
        x_label = "Flows as Server",
        y_label = "Flows as Client"
    }
}

return hosts_map_utils