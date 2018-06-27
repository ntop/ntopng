--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils"
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
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

-- NOTE: always disabled?
schema = ts_utils.newSchema("mac:ndpi_categories", {step=300})
schema:addTag("ifid")
schema:addTag("mac")
schema:addTag("category")
schema:addMetric("bytes", ts_utils.metrics.counter)

-------------------------------------------------------
-- HOST POOLS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host_pool:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("host_pool:blocked_flows", {step=300, rrd_fname="blocked_flows"})
schema:addTag("ifid")
schema:addTag("pool")
schema:addMetric("num_flows", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("host_pool:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("pool")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-------------------------------------------------------
-- ASN SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("asn:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("asn:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("asn")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("asn:rtt", {step=300, rrd_fname="num_ms_rtt"})
schema:addTag("ifid")
schema:addTag("asn")
schema:addMetric("millis_rtt", ts_utils.metrics.gauge)

-------------------------------------------------------
-- COUNTRIES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("country:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("country")
schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
schema:addMetric("bytes_egress", ts_utils.metrics.counter)
schema:addMetric("bytes_inner", ts_utils.metrics.counter)

-------------------------------------------------------
-- VLAN SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("vlan:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("vlan:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("vlan")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-------------------------------------------------------
-- FLOW DEVICES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("sflowdev_port:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("flowdev_port:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("port")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-------------------------------------------------------
-- SNMP SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("snmp_if:traffic", {step=300, rrd_heartbeat=3000, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("device")
schema:addTag("if_index")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host:traffic", {step=300, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("host:flows", {step=300, rrd_fname="num_flows"})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("num_flows", ts_utils.metrics.gauge)

-- ##############################################

-- NOTE: not shown
schema = ts_utils.newSchema("host:l4protos", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("l4proto")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("host:ndpi", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("protocol")
schema:addMetric("bytes_sent", ts_utils.metrics.counter)
schema:addMetric("bytes_rcvd", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("host:ndpi_categories", {step=300})
schema:addTag("ifid")
schema:addTag("host")
schema:addTag("category")
schema:addMetric("bytes", ts_utils.metrics.counter)
