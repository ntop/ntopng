--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils"

local ts_schemas = {}
local schema

-------------------------------------------------------
-- PROFILES SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("profile:traffic", {step=60, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("profile")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.profile_traffic = schema

-------------------------------------------------------
-- SUBNETS SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("subnet:traffic", {step=60, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
schema:addMetric("bytes_egress", ts_utils.metrics.counter)
schema:addMetric("bytes_inner", ts_utils.metrics.counter)
ts_schemas.subnet_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("subnet:broadcast_traffic", {step=60, rrd_fname="broadcast_bytes"})
schema:addTag("ifid")
schema:addTag("subnet")
schema:addMetric("bytes_ingress", ts_utils.metrics.counter)
schema:addMetric("bytes_egress", ts_utils.metrics.counter)
schema:addMetric("bytes_inner", ts_utils.metrics.counter)
ts_schemas.subnet_broadcast_traffic = schema

-------------------------------------------------------
-- INTERFACES SCHEMAS
-------------------------------------------------------

schema = ts_utils.schema:new("iface:ndpi", {step=60})
schema:addTag("ifid")
schema:addTag("protocol")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.iface_ndpi = schema

-- ##############################################

schema = ts_utils.schema:new("iface:ndpi_categories", {step=60})
schema:addTag("ifid")
schema:addTag("category")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.iface_ndpi_categories = schema

-- ##############################################

-- NOTE: not shown
schema = ts_utils.schema:new("iface:local2remote", {step=60, rrd_fname="local2remote"})
schema:addTag("ifid")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.iface_local2remote = schema

-- ##############################################

-- NOTE: not shown
schema = ts_utils.schema:new("iface:remote2local", {step=60, rrd_fname="remote2local"})
schema:addTag("ifid")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.iface_remote2local = schema

-- ##############################################

schema = ts_utils.schema:new("iface:hosts", {step=60, rrd_fname="num_hosts"})
schema:addTag("ifid")
schema:addMetric("num_hosts", ts_utils.metrics.gauge)
ts_schemas.iface_hosts = schema

-- ##############################################

schema = ts_utils.schema:new("iface:devices", {step=60, rrd_fname="num_devices"})
schema:addTag("ifid")
schema:addMetric("num_devices", ts_utils.metrics.gauge)
ts_schemas.iface_devices = schema

-- ##############################################

schema = ts_utils.schema:new("iface:flows", {step=60, rrd_fname="num_flows"})
schema:addTag("ifid")
schema:addMetric("num_flows", ts_utils.metrics.gauge)
ts_schemas.iface_flows = schema

-- ##############################################

schema = ts_utils.schema:new("iface:http_hosts", {step=60, rrd_fname="num_http_hosts"})
schema:addTag("ifid")
schema:addMetric("num_hosts", ts_utils.metrics.gauge)
ts_schemas.iface_http_hosts = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_retransmissions", {step=60, rrd_fname="tcp_retransmissions"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_retransmissions = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_out_of_order", {step=60, rrd_fname="tcp_ooo"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_out_of_order = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_lost", {step=60, rrd_fname="tcp_lost"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_lost = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_syn", {step=60, rrd_fname="tcp_syn"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_syn = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_synack", {step=60, rrd_fname="tcp_synack"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_synack = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_finack", {step=60, rrd_fname="tcp_finack"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_finack = schema

-- ##############################################

schema = ts_utils.schema:new("iface:tcp_rst", {step=60, rrd_fname="tcp_rst"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_tcp_rst = schema

-- ##############################################

return ts_schemas
