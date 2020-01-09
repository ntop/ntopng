--
-- (C) 2019-20 - ntop.org
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

schema = ts_utils.newSchema("mac:arp_rqst_sent_rcvd_rpls", {step=300})
schema:addTag("ifid")
schema:addTag("mac")
schema:addMetric("request_packets_sent")
schema:addMetric("reply_packets_rcvd")

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

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_retransmissions", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_out_of_order", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_lost", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

-- ##############################################

schema = ts_utils.newSchema("asn:tcp_keep_alive", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

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
-- EVENT EXPORTER SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("evexporter_iface:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("exporter")
schema:addTag("ifname")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-------------------------------------------------------
-- SNMP SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("snmp_if:traffic", {step=300, rrd_heartbeat=3000, rrd_fname="bytes", is_system_schema = true})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

schema = ts_utils.newSchema("snmp_if:errors", {step=300, rrd_heartbeat=3000, is_system_schema = true})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("packets_disc")
schema:addMetric("packets_err")

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:active_flows", {step=300, rrd_fname="active_flows", metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:total_flows", {step=300, rrd_fname="total_flows"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_client")
schema:addMetric("flows_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:misbehaving_flows", {step = 300, rrd_fname = "misbehaving_flows"})
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

schema = ts_utils.newSchema("host:host_unreachable_flows", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("flows_as_server")
schema:addMetric("flows_as_client")

--##############################################

schema = ts_utils.newSchema("host:ndpi_flows", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("protocol")
schema:addMetric("num_flows")

--##############################################

schema = ts_utils.newSchema("host:echo_packets", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

--##############################################

schema = ts_utils.newSchema("host:echo_reply_packets", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

--##############################################

schema = ts_utils.newSchema("host:dns_qry_sent_rsp_rcvd", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("queries_packets")
schema:addMetric("replies_ok_packets")
schema:addMetric("replies_error_packets")

--##############################################

schema = ts_utils.newSchema("host:dns_qry_rcvd_rsp_sent", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("queries_packets")
schema:addMetric("replies_ok_packets")
schema:addMetric("replies_error_packets")

--##############################################

schema = ts_utils.newSchema("host:tcp_rx_stats", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("retransmission_packets")
schema:addMetric("out_of_order_packets")
schema:addMetric("lost_packets")

--##############################################

schema = ts_utils.newSchema("host:tcp_tx_stats", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("retransmission_packets")
schema:addMetric("out_of_order_packets")
schema:addMetric("lost_packets")

--##############################################

schema = ts_utils.newSchema("host:tcp_packets", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

--##############################################

schema = ts_utils.newSchema("host:udp_pkts", {step = 300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("packets_sent")
schema:addMetric("packets_rcvd")

--##############################################

schema = ts_utils.newSchema("host:total_alerts", {step = 300, rrd_fname = "total_alerts"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("alerts")

--##############################################

schema = ts_utils.newSchema("host:total_flow_alerts", {step = 300, rrd_fname = "total_flow_alerts"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("alerts")

--##############################################

schema = ts_utils.newSchema("host:engaged_alerts", {step = 300, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("alerts")

-- ##############################################

schema = ts_utils.newSchema("host:contacts", {step=300, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("num_as_client")
schema:addMetric("num_as_server")

-- ##############################################

schema = ts_utils.newSchema("host:l4protos", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("l4proto")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:udp_sent_unicast", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent_unicast")
schema:addMetric("bytes_sent_non_unicast")

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
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

-- NOTE: these are "virtual" schema, they do not correspond to actual timeseries
schema = ts_utils.newSchema("local_senders", {step=300, is_system_schema = true})
schema:addTag("ifid")

schema = ts_utils.newSchema("local_receivers", {step=300, is_system_schema = true})
schema:addTag("ifid")
