--
-- (C) 2019 - ntop.org
--

local ts_utils = require("ts_utils_core")

schema = ts_utils.newSchema("process:resident_memory", {step=60, metrics_type=ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("resident_bytes")
