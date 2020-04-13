--
-- (C) 2019-20 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

schema = ts_utils.newSchema("am_host:rtt_5mins", {
  step = 300,
  metrics_type = ts_utils.metrics.gauge,
  aggregation_function = ts_utils.aggregation.max,
  is_system_schema = true,
})

schema:addTag("ifid")
schema:addTag("host")
schema:addTag("measure")
schema:addMetric("millis_rtt")

-- ##############################################

schema = ts_utils.newSchema("am_host:http_stats_5mins", {
  step = 300,
  metrics_type = ts_utils.metrics.gauge,
  aggregation_function = ts_utils.aggregation.max,
  is_system_schema = true,
})

schema:addTag("ifid")
schema:addTag("host")
schema:addTag("measure")
schema:addMetric("lookup_ms")
schema:addMetric("other_ms")

-- ##############################################

schema = ts_utils.newSchema("am_host:https_stats_5mins", {
  step = 300,
  metrics_type = ts_utils.metrics.gauge,
  aggregation_function = ts_utils.aggregation.max,
  is_system_schema = true,
})

schema:addTag("ifid")
schema:addTag("host")
schema:addTag("measure")
schema:addMetric("lookup_ms")
schema:addMetric("connect_ms")
schema:addMetric("other_ms")
