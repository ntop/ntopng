--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils"
local ts_schemas = {}

-- TODO: remove rrd_fname after new paths migration
-- NOTE: when rrd_fname is empty, the last tag value is used as file name

-------------------------------------------------------
-- L3 DEVICES SCHEMAS
-------------------------------------------------------

-- NOTE: always disabled?
schema = ts_utils.schema:new("mac:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("mac")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.mac_traffic = schema

-- ##############################################

-- NOTE: always disabled?
schema = ts_utils.schema:new("mac:ndpi_categories", {step=300})
schema:addTag("ifid")
schema:addTag("mac")
schema:addTag("category")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.mac_ndpi_categories = schema

-------------------------------------------------------
-- HOST POOLS SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("host_pool:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.host_pool_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("host_pool:blocked_flows", {step=300, rrd_fname="blocked_flows"})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_flows", ts_utils.metrics.counter)
ts_schemas.host_pool_blocked_flows = schema

-- ##############################################

schema = ts_utils.schema:new("host_pool:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("pool")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.host_pool_ndpi = schema

-------------------------------------------------------
-- ASN SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("asn:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.asn_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("asn:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.asn_ndpi = schema

-- ##############################################

schema = ts_utils.schema:new("asn:rtt", {step=300, rrd_fname="num_ms_rtt"})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("millis_rtt", ts_utils.metrics.gauge)
ts_schemas.asn_rtt = schema

-------------------------------------------------------
-- COUNTRIES SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("country:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("country")
schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
schema:addMetric("bytes_egress", ts_utils.metrics.counter)
schema:addMetric("bytes_inner", ts_utils.metrics.counter)
ts_schemas.country_traffic = schema

-------------------------------------------------------
-- VLAN SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("vlan:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.vlan_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("vlan:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.vlan_ndpi = schema

-------------------------------------------------------
-- FLOW DEVICES SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("sflowdev_port:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.sflowdev_port_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("flowdev_port:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.flowdev_port_traffic = schema

-------------------------------------------------------
-- SNMP SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("snmp_if:traffic", {step=300, rrd_heartbeat=3000, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.snmp_if_traffic = schema

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("host:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.host_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("host:flows", {step=300, rrd_fname="num_flows"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("num_flows", ts_utils.metrics.gauge)
ts_schemas.host_flows = schema

-- ##############################################

-- NOTE: not shown
schema = ts_utils.schema:new("host:l4protos", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("l4proto")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.host_l4protos = schema

-- ##############################################

schema = ts_utils.schema:new("host:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)
ts_schemas.host_ndpi = schema

-- ##############################################

schema = ts_utils.schema:new("host:ndpi_categories", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("category")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.host_ndpi_categories = schema

-- ##############################################

return ts_schemas
