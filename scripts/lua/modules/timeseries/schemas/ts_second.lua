--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils"
local schema

-- ##############################################

schema = ts_utils.newSchema("iface:traffic", {step=1, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addMetric("bytes", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("iface:packets", {step=1, rrd_fname="packets"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)

-- ##############################################

schema = ts_utils.newSchema("iface:zmq_recv_flows", {step=1, rrd_fname="num_zmq_rcvd_flows"})
schema:addTag("ifid")
schema:addMetric("num_flows", ts_utils.metrics.gauge)

-- ##############################################

schema = ts_utils.newSchema("iface:drops", {step=1, rrd_fname="drops"})
schema:addTag("ifid")
schema:addMetric("packets", ts_utils.metrics.counter)
