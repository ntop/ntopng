--
-- (C) 2018 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- HOST vs HOST SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("host_vs_host:traffic", {step=60, metrics_type=ts_utils.metrics.counter})
schema:addTag("ifid")
schema:addTag("host1")
schema:addTag("host2")
schema:addMetric("bytes")
