--
-- (C) 2019 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- HASH_TABLES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("ht:duration", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("hash_table")
schema:addMetric("num_ms")

schema = ts_utils.newSchema("ht:num_calls", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("hash_table")
schema:addMetric("num_calls")

schema = ts_utils.newSchema("ht:num_skipped_calls", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("hash_table")
schema:addMetric("idle")
schema:addMetric("proto_detected")
schema:addMetric("periodic_update")

-------------------------------------------------------
-- FLOW USER SCRIPTS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("flow_user_script:duration", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("user_script")
schema:addTag("subdir")
schema:addMetric("num_ms")

schema = ts_utils.newSchema("flow_user_script:num_calls", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("user_script")
schema:addTag("subdir")
schema:addMetric("num_calls")

schema = ts_utils.newSchema("flow_user_script:total_stats", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("subdir")
schema:addMetric("num_ms")
schema:addMetric("num_calls")
