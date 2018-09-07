--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- INTERFACES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("iface:1d_delta_traffic_volume", {step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("bytes")

-- ##############################################

schema = ts_utils.newSchema("iface:1d_delta_flows", {step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("num_flows")

-------------------------------------------------------
-- HOSTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host:1d_delta_traffic_volume", {step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ##############################################

schema = ts_utils.newSchema("host:1d_delta_flows", {step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("num_flows")

-- ##############################################

schema = ts_utils.newSchema("host:1d_delta_contacts", {step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("as_client")
schema:addMetric("as_server")
