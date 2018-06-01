--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils"

local ts_schemas = {}
local schema

-- ##############################################

schema = ts_utils.schema:new("iface:traffic", {step=1, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addMetric("bytes", ts_utils.metrics.counter)
ts_schemas.iface_traffic = schema

-- ##############################################

schema = ts_utils.schema:new("iface:packets", {step=1, rrd_fname="packets"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_packets = schema

-- ##############################################

schema = ts_utils.schema:new("iface:zmq_recv_flows", {step=1, rrd_fname="num_zmq_rcvd_flows"})
schema:addTag("ifid")
schema:addMetric("num_flows", ts_utils.metrics.gauge)
ts_schemas.iface_zmq_recv_flows = schema

-- ##############################################

schema = ts_utils.schema:new("iface:drops", {step=1, rrd_fname="drops"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
ts_schemas.iface_drops = schema

-- ##############################################

return ts_schemas
