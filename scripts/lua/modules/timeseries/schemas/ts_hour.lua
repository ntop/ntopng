--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-- ##############################################

schema = ts_utils.newSchema("iface:rsi_traffic", {step=60, insertion_step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("rsi")

-- ##############################################

schema = ts_utils.newSchema("host:rsi_traffic", {step=60, insertion_step=3600, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("rsi")
