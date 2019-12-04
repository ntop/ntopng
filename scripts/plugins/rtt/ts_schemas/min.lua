--
-- (C) 2019 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

schema = ts_utils.newSchema("monitored_host:rtt", {
  step = 60,
  metrics_type = ts_utils.metrics.gauge,
  aggregation_function = ts_utils.aggregation.max,
  is_system_schema = true,
})

schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("millis_rtt")
