--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- PROFILES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("profile:traffic", {step=60, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("profile")
schema:addMetric("bytes")

-------------------------------------------------------
-- SUBNETS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("subnet:traffic", {step=60, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")
schema:addMetric("bytes_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:broadcast_traffic", {step=60, rrd_fname="broadcast_bytes"})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")
schema:addMetric("bytes_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_retransmissions", {step=60})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_out_of_order", {step=60})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_lost", {step=60})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-- ##############################################

schema = ts_utils.newSchema("subnet:tcp_keep_alive", {step=60})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("packets_ingress")
schema:addMetric("packets_egress")
schema:addMetric("packets_inner")

-------------------------------------------------------
-- INTERFACES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("iface:ndpi", {step=60})
schema:addTag("ifid")
schema:addTag("protocol")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:ndpi_categories", {step=60})
schema:addTag("ifid")
schema:addTag("category")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:l4protos", {step=60})
schema:addTag("ifid")
schema:addTag("l4proto")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:ndpi_flows", {step=60})
schema:addTag("ifid")
schema:addTag("protocol")
schema:addMetric("num_flows")

-- ##############################################

-- NOTE: not shown
schema = ts_utils.newSchema("iface:local2remote", {step=60, rrd_fname="local2remote"})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

-- NOTE: not shown
schema = ts_utils.newSchema("iface:remote2local", {step=60, rrd_fname="remote2local"})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:hosts", {step=60, rrd_fname="num_hosts", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("iface:local_hosts", {step=60, rrd_fname="num_local_hosts", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("iface:devices", {step=60, rrd_fname="num_devices", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_devices")

-- ##############################################

schema = ts_utils.newSchema("iface:flows", {step=60, rrd_fname="num_flows", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:http_hosts", {step=60, rrd_fname="num_http_hosts", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_retransmissions", {step=60, rrd_fname="tcp_retransmissions"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_out_of_order", {step=60, rrd_fname="tcp_ooo"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_lost", {step=60, rrd_fname="tcp_lost"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_syn", {step=60, rrd_fname="tcp_syn"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_synack", {step=60, rrd_fname="tcp_synack"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_finack", {step=60, rrd_fname="tcp_finack"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:tcp_rst", {step=60, rrd_fname="tcp_rst"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:nfq_pct", {step=60, rrd_fname="num_nfq_pct", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_nfq_pct")

-- ##############################################

-------------------------------------------------------
-- CONTAINERS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("container:num_flows", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("container")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("container:rtt", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("container")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("container:rtt_variance", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("container")
schema:addMetric("as_client")
schema:addMetric("as_server")

-------------------------------------------------------
-- PODS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("pod:num_containers", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("num_containers")

schema = ts_utils.newSchema("pod:num_flows", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("pod:rtt", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("as_client")
schema:addMetric("as_server")

schema = ts_utils.newSchema("pod:rtt_variance", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("pod")
schema:addMetric("as_client")
schema:addMetric("as_server")

-------------------------------------------------------
-- PROCESS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("process:memory", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("resident_bytes")
schema:addMetric("virtual_bytes")
