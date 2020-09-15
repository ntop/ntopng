--
-- (C) 2020 - ntop.org
--

-- This file contains timeseries defintions which have minute granularity

local ts_utils = require "ts_utils_core"
local schema

-- Define a schema "example:active_hosts" as a gauge (suitable for
-- instant values).
schema = ts_utils.newSchema("example:active_hosts", {
  step = 60,
  metrics_type = ts_utils.metrics.gauge,
})

schema:addTag("ifid")
schema:addMetric("num_hosts")

-- ##############################################

-- Define a schema "example:num_requests" as counter (suitable for
-- cumulative values)
schema = ts_utils.newSchema("example:num_requests", {
  step = 60,
  metrics_type = ts_utils.metrics.counter,
})

schema:addTag("ifid")
schema:addTag("endpoint")
schema:addMetric("as_client")
schema:addMetric("as_server")
