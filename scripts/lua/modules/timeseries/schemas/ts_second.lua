--
-- (C) 2021 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-- ##############################################

schema = ts_utils.newSchema("iface:traffic", {step=1, rrd_fname="bytes", is_critical_ts=true})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:traffic_rxtx", {step=1, is_critical_ts=true})
schema:addTag("ifid")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("iface:packets", {step=1, rrd_fname="packets", is_critical_ts=true})
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

schema = ts_utils.newSchema("iface:packets_vs_drops", {step=1, is_critical_ts=true})
schema:addTag("ifid")
schema:addMetric("packets")
schema:addMetric("drops")

-- ##############################################

-- Discarded Probing bytes
schema = ts_utils.newSchema("iface:disc_prob_bytes", {step = 1, rrd_fname = "disc_prob_bytes"})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

-- Discarded Probing packets
schema = ts_utils.newSchema("iface:disc_prob_pkts", {step = 1, rrd_fname = "disc_prob_pkts"})
schema:addTag("ifid")
schema:addMetric("packets")
