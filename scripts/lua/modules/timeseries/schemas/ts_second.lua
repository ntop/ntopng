--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-- ##############################################

schema = ts_utils.newSchema("iface:traffic", {step=1, rrd_fname="bytes"})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:traffic_rxtx", {step=1})
schema:addTag("ifid")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("iface:packets", {step=1, rrd_fname="packets"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("iface:zmq_recv_flows", {step=1, rrd_fname = "zmq_rcvd_flows"})
schema:addTag("ifid")
schema:addMetric("flows")

-- ##############################################

schema = ts_utils.newSchema("iface:zmq_rcvd_msgs", {step=1, rrd_fname = "zmq_rcvd_msgs"})
schema:addTag("ifid")
schema:addMetric("msgs")

-- ##############################################

schema = ts_utils.newSchema("iface:zmq_msg_drops", {step=1, rrd_fname = "zmq_msg_drops"})
schema:addTag("ifid")
schema:addMetric("msgs")

-- ##############################################

schema = ts_utils.newSchema("iface:zmq_flow_coll_drops", {step = 1, rrd_fname = "zmq_flow_coll_drops"})
schema:addTag("ifid")
schema:addMetric("drops")

-- ##############################################

schema = ts_utils.newSchema("iface:zmq_flow_coll_udp_drops", {step = 1, rrd_fname = "zmq_flow_udp_drops"})
schema:addTag("ifid")
schema:addMetric("drops")

-- ##############################################

schema = ts_utils.newSchema("iface:exported_flows", {step=1, rrd_fname="exported_flows"})
schema:addTag("ifid")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:dropped_flows", {step=1, rrd_fname="dropped_flows"})
schema:addTag("ifid")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("iface:drops", {step=1, rrd_fname="drops"})
schema:addTag("ifid")
schema:addMetric("packets")

-- ##############################################

schema = ts_utils.newSchema("system:cpu_load", {step=1, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("load_percentage")
