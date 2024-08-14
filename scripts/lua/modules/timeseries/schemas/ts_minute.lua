--
-- (C) 2019-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- PERIODIC_SCRIPTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("periodic_script:duration", {
    step = 60,
    rrd_fname = "ps_duration",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("periodic_script")
schema:addMetric("num_ms_last")

schema = ts_utils.newSchema("periodic_script:timeseries_writes", {
    step = 60,
    rrd_fname = "ps_ts_wrdr",
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("periodic_script")
schema:addMetric("writes")
schema:addMetric("drops")

-------------------------------------------------------
-- HASH_TABLES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("ht:state", {
    step = 60,
    rrd_fname = "ht_state",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("hash_table")
schema:addMetric("num_idle")
schema:addMetric("num_active")

-------------------------------------------------------
-- MEMORY AND ALERT SCHEMAS ('/callbacks/minute/system/timeseries.lua')
-------------------------------------------------------

-- ################################################

schema = ts_utils.newSchema("process:resident_memory", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("resident_bytes")

-- ################################################

schema = ts_utils.newSchema("process:num_alerts", {
    step = 60
})
schema:addTag("ifid")
schema:addMetric("written_alerts")
schema:addMetric("alerts_queries")
schema:addMetric("dropped_alerts")

-------------------------------------------------------
-- PROFILES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("profile:traffic", {
    step = 60,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("profile")
schema:addMetric("bytes")

-------------------------------------------------------
-- nEDGE SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("iface:nedge_traffic_rxtx", {
    step = 60
})
schema:addTag("ifid")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

schema = ts_utils.newSchema("iface:nedge_traffic_nfq", {
    step = 60
})
schema:addTag("ifid")
schema:addMetric("bytes")
schema:addMetric("bytes_nfq")

-------------------------------------------------------
-- SUBNETS SCHEMAS
-------------------------------------------------------

if ntop.isPro() then
    schema = ts_utils.newSchema("subnet:intranet_traffic_min", {
        step = 60,
        metrics_type = ts_utils.metrics.counter
    })
    schema:addTag("ifid")
    schema:addTag("subnet")
    schema:addTag("subnet_2")
    schema:addMetric("bytes_sent")
    schema:addMetric("bytes_rcvd")
end

-- ##############################################

schema = ts_utils.newSchema("subnet:rtt", {
    step = 300,
    rrd_fname = "num_ms_rtt",
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("millis_rtt")

-- ##############################################

schema = ts_utils.newSchema("subnet:traffic", {
    step = 60,
    rrd_fname = "bytes"
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")
schema:addMetric("bytes_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:broadcast_traffic", {
    step = 60,
    rrd_fname = "broadcast_bytes"
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")
schema:addMetric("bytes_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_retransmissions", {
    step = 60
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_out_of_order", {
    step = 60
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_lost", {
    step = 60
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_keep_alive", {
    step = 60
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:engaged_alerts", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("alerts")

-- ##############################################

schema = ts_utils.newSchema("subnet:score", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("score")
schema:addMetric("scoreAsClient")
schema:addMetric("scoreAsServer")

-------------------------------------------------------
-- INTERFACES SCHEMAS
-------------------------------------------------------

if ntop.isEnterpriseM() then

    -- ##############################################

    schema = ts_utils.newSchema("iface:score_anomalies_v2", {
        step = 60,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("iface:score_behavior_v2", {
        step = 300,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("iface:traffic_anomalies_v2", {
        step = 60,
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addMetric("anomaly")

    -- ##############################################

    schema = ts_utils.newSchema("iface:traffic_tx_behavior_v5", {
        step = 60,
        metrics_type = ts_utils.metrics.gauge,
        keep_total = true
    })
    schema:addTag("ifid")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")

    -- ##############################################

    schema = ts_utils.newSchema("iface:traffic_rx_behavior_v5", {
        step = 60,
        metrics_type = ts_utils.metrics.gauge,
        keep_total = true
    })
    schema:addTag("ifid")
    schema:addMetric("value")
    schema:addMetric("lower_bound")
    schema:addMetric("upper_bound")
end

schema = ts_utils.newSchema("iface:ndpi", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("protocol")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:ndpi_categories", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("category")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:l4protos", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("l4proto")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:ndpi_flows", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addTag("protocol")
schema:addMetric("num_flows")

-- ##############################################

-- NOTE: not shown
schema = ts_utils.newSchema("iface:local2remote", {
    step = 60,
    rrd_fname = "local2remote"
})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

-- NOTE: not shown
schema = ts_utils.newSchema("iface:remote2local", {
    step = 60,
    rrd_fname = "remote2local"
})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:hosts", {
    step = 60,
    rrd_fname = "num_hosts",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("iface:local_hosts", {
    step = 60,
    rrd_fname = "num_local_hosts",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("iface:devices", {
    step = 60,
    rrd_fname = "num_devices",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_devices")

-- ##############################################

schema = ts_utils.newSchema("iface:flows", {
    step = 60,
    rrd_fname = "num_flows",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:alerted_flows", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:new_flows", {
    step = 60,
    rrd_fname = "if_new_flows",
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("new_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:http_hosts", {
    step = 60,
    rrd_fname = "num_http_hosts",
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_retransmissions", {
    step = 60,
    rrd_fname = "tcp_retransmissions"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_out_of_order", {
    step = 60,
    rrd_fname = "tcp_ooo"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_lost", {
    step = 60,
    rrd_fname = "tcp_lost"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_keep_alive", {
    step = 60,
    rrd_fname = "tcp_keepalive"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_syn", {
    step = 60,
    rrd_fname = "tcp_syn"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_synack", {
    step = 60,
    rrd_fname = "tcp_synack"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_finack", {
    step = 60,
    rrd_fname = "tcp_finack"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_rst", {
    step = 60,
    rrd_fname = "tcp_rst"
})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:nfq_pct", {
    step = 60,
    rrd_fname = "num_nfq_pct",
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addMetric("num_nfq_pct")

-- ##############################################

schema = ts_utils.newSchema("iface:score", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addMetric("cli_score")
schema:addMetric("srv_score")

-- ##############################################

schema = ts_utils.newSchema("iface:engaged_alerts", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("engaged_alerts")

-- ##############################################

schema = ts_utils.newSchema("iface:dropped_alerts", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("dropped_alerts")

-- ##############################################

schema = ts_utils.newSchema("iface:dumped_flows", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("dumped_flows")
schema:addMetric("dropped_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:hosts_anomalies", {
    step = 60,
    is_critical_ts = true
})
schema:addTag("ifid")
schema:addMetric("num_loc_hosts_anom")
schema:addMetric("num_rem_hosts_anom")

-- ##############################################

schema = ts_utils.newSchema("am_host:val_min", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge,
    aggregation_function = ts_utils.aggregation.max,
    is_system_schema = true
})

schema:addTag("ifid")
schema:addTag("host")
schema:addTag("metric")
schema:addMetric("value")

-- ##############################################

schema = ts_utils.newSchema("am_host:http_stats_min", {
    step = 60,
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

schema = ts_utils.newSchema("am_host:https_stats_min", {
    step = 60,
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

schema = ts_utils.newSchema("am_host:cicmp_stats_min", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})

schema:addTag("ifid")
schema:addTag("host")
schema:addTag("metric")
schema:addMetric("min_rtt")
schema:addMetric("max_rtt")

-- ##############################################

schema = ts_utils.newSchema("am_host:jitter_stats_min", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true
})

schema:addTag("ifid")
schema:addTag("host")
schema:addTag("metric")
schema:addMetric("latency")
schema:addMetric("jitter")

-- ##############################################

-------------------------------------------------------
-- CONTAINERS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("container:num_flows", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("container")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("container:rtt", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("container")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("container:rtt_variance", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("container")
schema:addMetric("as_client")
schema:addMetric("as_server")

-------------------------------------------------------
-- PODS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("pod:num_containers", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("num_containers")

schema = ts_utils.newSchema("pod:num_flows", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("pod:rtt", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("pod:rtt_variance", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge
})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("as_client")
schema:addMetric("as_server")

-- ################################################

-------------------------------------------------------
-- REDIS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("redis:memory", {
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true,
    step = 60
})
schema:addTag("ifid")
schema:addMetric("resident_bytes")

-- ################################################

schema = ts_utils.newSchema("redis:keys", {
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true,
    step = 60
})
schema:addTag("ifid")
schema:addMetric("num_keys")

-- ################################################

-- Cache
schema = ts_utils.newSchema("redis:hits", {
    metrics_type = ts_utils.metrics.gauge,
    is_system_schema = true,
    step = 60
})
schema:addTag("ifid")
schema:addTag("command")
schema:addMetric("num_calls")

-- ################################################

-- SNMP
schema = ts_utils.newSchema("snmp_if:traffic_min", {
    step = 60,
    rrd_heartbeat = 600,
    rrd_fname = "bytes_per_minute",
    is_system_schema = true
})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

-------------------------------------------------------
-- FLOW PROBES SCHEMAS
-------------------------------------------------------

if ntop.isEnterpriseM() then
    schema = ts_utils.newSchema("flowdev:traffic_min", {
        step = 60,
        rrd_fname = "bytes_min"
    })
    schema:addTag("ifid")
    schema:addTag("device")
    schema:addMetric("bytes_sent")
    schema:addMetric("bytes_rcvd")

    -- ##############################################

    schema = ts_utils.newSchema("flowdev:drops_min", {
        step = 60,
        rrd_fname = "drops_min"
    })
    schema:addTag("ifid")
    schema:addTag("device")
    schema:addMetric("drops")

    -- ##############################################

    schema = ts_utils.newSchema("flowdev:flows_min", {
        step = 60,
        rrd_fname = "flows_min"
    })
    schema:addTag("ifid")
    schema:addTag("device")
    schema:addMetric("flows")

    -- ##############################################

    schema = ts_utils.newSchema("flowdev_port:traffic_min", {
        step = 60,
        rrd_fname = "bytes_min"
    })
    schema:addTag("ifid")
    schema:addTag("device")
    schema:addTag("port")
    schema:addMetric("bytes_sent")
    schema:addMetric("bytes_rcvd")

    schema = ts_utils.newSchema("flowdev_port:usage_min", {
        step = 60,
        rrd_fname = "usage_min",
        metrics_type = ts_utils.metrics.gauge
    })
    schema:addTag("ifid")
    schema:addTag("device")
    schema:addTag("port")
    schema:addMetric("uplink")
    schema:addMetric("downlink")

    schema = ts_utils.newSchema("flowdev_port:ndpi_min", {
        step = 60
    })
    schema:addTag("ifid")
    schema:addTag("device")
    schema:addTag("port")
    schema:addTag("protocol")
    schema:addMetric("bytes_sent")
    schema:addMetric("bytes_rcvd")
end
