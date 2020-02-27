--
-- (C) 2019-20 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- SYSTEM CPU states
-------------------------------------------------------

schema = ts_utils.newSchema("system:iowait", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addMetric("iowait_pct")

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
schema:addTag("subdir") -- NOTE: needed by user_scripts.ts_dump
schema:addMetric("num_calls")

schema = ts_utils.newSchema("flow_user_script:total_stats", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("subdir") -- NOTE: needed by user_scripts.ts_dump
schema:addMetric("num_ms")
schema:addMetric("num_calls")

-------------------------------------------------------
-- FLOW USER SCRIPT SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("flow_script:skipped_calls", {step = 5, metrics_type = ts_utils.metrics.gauge, is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("idle")
schema:addMetric("proto_detected")
schema:addMetric("periodic_update")

schema = ts_utils.newSchema("flow_script:pending_calls", {step = 5, metrics_type = ts_utils.metrics.gauge, is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("proto_detected")
schema:addMetric("periodic_update")

schema = ts_utils.newSchema("flow_script:successful_calls", {step = 5, metrics_type = ts_utils.metrics.gauge, is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("num_calls")

schema = ts_utils.newSchema("flow_script:lua_duration", {step = 5, metrics_type = ts_utils.metrics.gauge, is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("num_ms")
