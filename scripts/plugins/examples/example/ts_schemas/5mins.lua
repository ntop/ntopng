--
-- (C) 2020 - ntop.org
--

-- This file contains timeseries defintions which have 5 minutes granularity

local ts_utils = require "ts_utils_core"
local schema

-- Define a schema "host:total_hops" as a counter (suitable for
-- cumulative values).
schema = ts_utils.newSchema("host:total_hops", {
  step = 300,
  metrics_type = ts_utils.metrics.counter,
})

-- The record identifiers
schema:addTag("ifid")
schema:addTag("host")
-- The values
schema:addMetric("num_hops")
