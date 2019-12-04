local schema
local ts_utils = require("ts_utils_core")

schema = ts_utils.newSchema("redis:memory", {
  metrics_type = ts_utils.metrics.gauge,
  is_system_schema = true,
  step = 60,
})
schema:addTag("ifid")
schema:addMetric("resident_bytes")

schema = ts_utils.newSchema("redis:keys", {
  metrics_type = ts_utils.metrics.gauge,
  is_system_schema = true,
  step = 60,
})
schema:addTag("ifid")
schema:addMetric("num_keys")

-- Cache
schema = ts_utils.newSchema("redis:hits", {
  metrics_type = ts_utils.metrics.gauge,
  is_system_schema = true,
  step = 60,
})
schema:addTag("ifid")
schema:addTag("command")
schema:addMetric("num_calls")
