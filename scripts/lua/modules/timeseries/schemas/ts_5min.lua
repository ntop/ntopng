--
-- (C) 2019-22 - ntop.org
--
local ts_utils = require "ts_utils_core"
local schema

-- TODO: remove rrd_fname after new paths migration
-- NOTE: when rrd_fname is empty, the last tag value is used as file name

-------------------------------------------------------
-- L3 DEVICES SCHEMAS
-------------------------------------------------------

-- NOTE: always disabled?
schema = ts_utils.newSchema("mac:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("mac")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("mac:arp_rqst_sent_rcvd_rpls", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("mac")
schema:addMetric("request_pkts_sent")
schema:addMetric("reply_pkts_rcvd")

-- ##############################################

-- NOTE: always disabled?
schema = ts_utils.newSchema("mac:ndpi_categories", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("mac")
schema:addTag("category")
schema:addMetric("bytes")

-------------------------------------------------------
-- HOST POOLS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host_pool:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host_pool:hosts", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("host_pool:devices", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_devices")

-- ##############################################

schema = ts_utils.newSchema("host_pool:blocked_flows", {
    step = 300,
    rrd_fname = "blocked_flows"
})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("host_pool:ndpi", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("pool")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- ASN SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("asn:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:score", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("score")
schema:addMetric("scoreAsClient")
schema:addMetric("scoreAsServer")

-- ##############################################

schema = ts_utils.newSchema("asn:traffic_sent", {
    step = 300,
    rrd_fname = "bytes_sent"
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("asn:traffic_rcvd", {
    step = 300,
    rrd_fname = "bytes_rcvd"
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("asn:ndpi", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:rtt", {
    step = 300,
    rrd_fname = "num_ms_rtt",
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("millis_rtt")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_retransmissions", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_out_of_order", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_lost", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_keep_alive", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

-------------------------------------------------------
-- COUNTRIES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("country:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("country")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")
schema:addMetric("bytes_inner")

-- ##############################################

schema = ts_utils.newSchema("country:score", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("country")
schema:addMetric("score")
schema:addMetric("scoreAsClient")
schema:addMetric("scoreAsServer")

-------------------------------------------------------
-- OBS POINT SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("obs_point:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("obs_point")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("obs_point:score", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("obs_point")
schema:addMetric("score")
schema:addMetric("scoreAsClient")
schema:addMetric("scoreAsServer")

-- ##############################################

schema = ts_utils.newSchema("obs_point:traffic_sent", {
    step = 300,
    rrd_fname = "bytes_sent"
})
schema:addTag("ifid")
schema:addTag("obs_point")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("obs_point:traffic_rcvd", {
    step = 300,
    rrd_fname = "bytes_rcvd"
})
schema:addTag("ifid")
schema:addTag("obs_point")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("obs_point:ndpi", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("obs_point")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- OSES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("os:traffic", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("os")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")

-------------------------------------------------------
-- VLAN SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("vlan:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("vlan:score", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addMetric("score")
schema:addMetric("scoreAsClient")
schema:addMetric("scoreAsServer")

-- ##############################################

schema = ts_utils.newSchema("vlan:ndpi", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- FLOW PROBES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("sflowdev_port:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("flowdev_port:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

schema = ts_utils.newSchema("flowdev_port:ndpi", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- EVENT EXPORTER SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("evexporter_iface:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("exporter")
schema:addTag("ifname")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- SNMP SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("snmp_if:traffic", {
    step = 300,
    rrd_heartbeat = 3000,
    rrd_fname = "bytes",
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

schema = ts_utils.newSchema("snmp_if:packets", {
    step = 300,
    rrd_heartbeat = 3000,
    rrd_fname = "packets",
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("ucast_sent")
schema:addMetric("nucast_sent")
schema:addMetric("ucast_rcvd")
schema:addMetric("nucast_rcvd")

schema = ts_utils.newSchema("snmp_if:errors", {
    step = 300,
    rrd_heartbeat = 3000,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("packets_disc")
schema:addMetric("packets_err")

schema = ts_utils.newSchema("snmp_dev:cpu_states", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addMetric("user_pct")
schema:addMetric("system_pct")
schema:addMetric("idle_pct")

schema = ts_utils.newSchema("snmp_dev:avail_memory", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addMetric("avail_bytes")

schema = ts_utils.newSchema("snmp_dev:swap_memory", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addMetric("swap_bytes")

schema = ts_utils.newSchema("snmp_dev:total_memory", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addMetric("total_bytes")

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host:traffic", {
    step = 300,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:score", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("score_as_cli")
schema:addMetric("score_as_srv")

-- ##############################################

schema = ts_utils.newSchema("host:active_flows", {
    step = 300,
    rrd_fname = "active_flows",
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:num_blacklisted_flows", {
    step = 300,
    rrd_fname = "num_blacklisted_flows"
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:total_flows", {
    step = 300,
    rrd_fname = "total_flows"
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:alerted_flows", {
    step = 300,
    rrd_fname = "alerted_flows"
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:unreachable_flows", {
    step = 300,
    rrd_fname = "unreachable_flows"
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:host_unreachable_flows", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_server")
schema:addMetric("flows_as_client")

-- ##############################################

schema = ts_utils.newSchema("host:host_tcp_unidirectional_flows", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_server")
schema:addMetric("flows_as_client")

-- ##############################################

schema = ts_utils.newSchema("host:ndpi_flows", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("protocol")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("host:echo_packets", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:echo_reply_packets", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:dns_qry_sent_rsp_rcvd", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("queries_pkts")
schema:addMetric("replies_ok_pkts")
schema:addMetric("replies_error_pkts")

-- ##############################################

schema = ts_utils.newSchema("host:dns_qry_rcvd_rsp_sent", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("queries_pkts")
schema:addMetric("replies_ok_pkts")
schema:addMetric("replies_error_pkts")

-- ##############################################

schema = ts_utils.newSchema("host:tcp_rx_stats", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("retran_pkts")
schema:addMetric("out_of_order_pkts")
schema:addMetric("lost_packets")

-- ##############################################

schema = ts_utils.newSchema("host:tcp_tx_stats", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("retran_pkts")
schema:addMetric("out_of_order_pkts")
schema:addMetric("lost_packets")

-- ##############################################

schema = ts_utils.newSchema("host:tcp_packets", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:udp_pkts", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:total_alerts", {
    step = 300,
    rrd_fname = "total_alerts"
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("alerts")

-- ##############################################

schema = ts_utils.newSchema("host:engaged_alerts", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("alerts")

-- ##############################################

schema = ts_utils.newSchema("host:contacts", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("num_as_client")
schema:addMetric("num_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:l4protos", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("l4proto")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:dscp", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("dscp_class")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:udp_sent_unicast", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent_unicast")
schema:addMetric("bytes_sent_non_uni")

-- ##############################################

schema = ts_utils.newSchema("host:ndpi", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:ndpi_categories", {
    step = 300
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("category")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

-- NOTE: these are "virtual" schema, they do not correspond to actual timeseries
schema = ts_utils.newSchema("local_senders", {
    step = 300,
    is_system_schema = true
})
schema:addTag("ifid")

schema = ts_utils.newSchema("local_receivers", {
    step = 300,
    is_system_schema = true
})
schema:addTag("ifid")

schema = ts_utils.newSchema("am_host:val_5mins", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    aggregation_function = ts_utils.aggregation.max,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("metric")
schema:addMetric("value")

-- ##############################################

-------------------------------------------------------
-- INFLUXDB SCHEMAS
-------------------------------------------------------

-- ##############################################

schema = ts_utils.newSchema("am_host:http_stats_5mins", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    aggregation_function = ts_utils.aggregation.max,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("metric")
schema:addMetric("lookup_ms")
schema:addMetric("other_ms")

-- ##############################################

schema = ts_utils.newSchema("am_host:https_stats_5mins", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    aggregation_function = ts_utils.aggregation.max,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("metric")
schema:addMetric("lookup_ms")
schema:addMetric("connect_ms")
schema:addMetric("other_ms")

-- ##############################################

schema = ts_utils.newSchema("am_host:upload_5mins", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("speed")

-- ##############################################

schema = ts_utils.newSchema("am_host:latency_5mins", {
    step = 300,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("latency")

-------------------------------------------------------
-- INFLUXDB SCHEMAS
-------------------------------------------------------

-- ##############################################

schema = ts_utils.newSchema("influxdb:storage_size", {
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true,
    step = 300
})
schema:addTag("ifid")
schema:addMetric("disk_bytes")

-- ##############################################

schema = ts_utils.newSchema("influxdb:exported_points", {
    metrics_type = ts_utils.metrics.counter,
    is_system_schema = true,
    step = 300
})
schema:addTag("ifid")
schema:addMetric("points")

-- ##############################################

schema = ts_utils.newSchema("influxdb:dropped_points", {
    metrics_type = ts_utils.metrics.counter,
    is_system_schema = true,
    step = 300
})
schema:addTag("ifid")
schema:addMetric("points")

-- ##############################################

schema = ts_utils.newSchema("influxdb:exports", {
    metrics_type = ts_utils.metrics.counter,
    is_system_schema = true,
    step = 300
})
schema:addTag("ifid")
schema:addMetric("num_exports")

-- ##############################################

schema = ts_utils.newSchema("influxdb:rtt", {
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true,
    step = 300
})
schema:addTag("ifid")
schema:addMetric("millis_rtt")

-- ##############################################

-- The following metrics are built-in into influxdb
schema = ts_utils.newSchema("influxdb:memory_size", {
    influx_internal_query = ts_utils.get_memory_size_query,
    is_system_schema = true,
    metrics_type = ts_utils.metrics.gauge,
    step = 10
})
schema:addTag("ifid")
schema:addMetric("mem_bytes")

-- ##############################################

schema = ts_utils.newSchema("influxdb:write_successes", {
    influx_internal_query = ts_utils.get_write_success_query,
    is_system_schema = true,
    metrics_type = ts_utils.metrics.counter,
    step = 10
})
schema:addTag("ifid")
schema:addMetric("points")

-------------------------------------------------------
-- PRO VERSION SCHEMAS
-------------------------------------------------------

-- ##############################################

if ntop.isPro() then
    -------------------------------------------------------
    -- ASN SCHEMAS
    -------------------------------------------------------

    schema = ts_utils.newSchema("asn:traffic_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("asn")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("asn:traffic_tx_behavior_v2", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("asn")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("asn:traffic_rx_behavior_v2", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("asn")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("asn:score_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("asn")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("asn:score_behavior", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("asn")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -------------------------------------------------------
    -- INTERFACE SCHEMAS
    -------------------------------------------------------

    -------------------------------------------------------
    -- SUBNET SCHEMAS
    -------------------------------------------------------

    schema = ts_utils.newSchema("subnet:traffic_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("subnet")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("subnet:traffic_tx_behavior_v2", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("subnet")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("subnet:traffic_rx_behavior_v2", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("subnet")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("subnet:score_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("subnet")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("subnet:score_behavior", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("subnet")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -------------------------------------------------------
    -- HOST SCHEMAS
    -------------------------------------------------------

    schema = ts_utils.newSchema("host:contacts_behaviour", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("host:cli_active_flows_behaviour", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("host:srv_active_flows_behaviour", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("host:cli_score_behaviour", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("host:srv_score_behaviour", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")
    -- ##############################################

    schema = ts_utils.newSchema("host:cli_active_flows_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("host:srv_active_flows_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("host:cli_score_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("host:srv_score_anomalies", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("host")
    schema:addMetric("anomaly")

end
