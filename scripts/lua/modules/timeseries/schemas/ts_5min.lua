--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-- TODO: remove rrd_fname after new paths migration
-- NOTE: when rrd_fname is empty, the last tag value is used as file name

-------------------------------------------------------
-- L3 DEVICES SCHEMAS
-------------------------------------------------------

-- NOTE: always disabled?
schema = ts_utils.newSchema("mac:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("mac")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

-- NOTE: always disabled?
schema = ts_utils.newSchema("mac:ndpi_categories", {step=300})
schema:addTag("ifid")
schema:addTag("mac")
schema:addTag("category")
schema:addMetric("bytes")

-------------------------------------------------------
-- HOST POOLS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host_pool:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host_pool:hosts", {step = 300, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_hosts")

-- ##############################################

schema = ts_utils.newSchema("host_pool:devices", {step = 300, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_devices")

-- ##############################################

schema = ts_utils.newSchema("host_pool:blocked_flows", {step=300, rrd_fname="blocked_flows"})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("host_pool:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("pool")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- ASN SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("asn:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:rtt", {step=300, rrd_fname="num_ms_rtt", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("millis_rtt")

-------------------------------------------------------
-- COUNTRIES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("country:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("country")
schema:addMetric("bytes_ingress")
schema:addMetric("bytes_egress")
schema:addMetric("bytes_inner")

-------------------------------------------------------
-- VLAN SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("vlan:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("vlan:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- FLOW DEVICES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("sflowdev_port:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("flowdev_port:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- SNMP SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("snmp_if:traffic", {step=300, rrd_heartbeat=3000, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:flows", {step=300, rrd_fname="num_flows", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("host:anomalous_flows", {step = 300, rrd_fname = "anomalous_flows"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:unreachable_flows", {step = 300, rrd_fname = "unreachable_flows"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:net_unreachable_flows", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_server")
schema:addMetric("flows_as_client")

--##############################################

schema = ts_utils.newSchema("host:host_unreachable_flows", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_server")
schema:addMetric("flows_as_client")

--##############################################

schema = ts_utils.newSchema("host:dns_sent", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("queries_packets")
schema:addMetric("replies_ok_packets")
schema:addMetric("replies_error_packets")

--##############################################

schema = ts_utils.newSchema("host:dns_rcvd", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("queries_packets")
schema:addMetric("replies_ok_packets")
schema:addMetric("replies_error_packets")

--##############################################

schema = ts_utils.newSchema("host:total_alerts", {step = 300, rrd_fname = "total_alerts"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("alerts")

-- ##############################################

schema = ts_utils.newSchema("host:contacts", {step=300, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("as_client")
schema:addMetric("as_server")

-- ##############################################

schema = ts_utils.newSchema("host:l4protos", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("l4proto")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("protocol")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:ndpi_categories", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("category")
schema:addMetric("bytes")

-- ##############################################

-- NOTE: these are "virtual" schema, they do not correspond to actual timeseries
schema = ts_utils.newSchema("local_senders", {step=300})
schema:addTag("ifid")

schema = ts_utils.newSchema("local_receivers", {step=300})
schema:addTag("ifid")
