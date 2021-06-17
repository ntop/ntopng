--
-- (C) 2019-21 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- SYSTEM CPU states and load
-------------------------------------------------------

schema = ts_utils.newSchema("system:cpu_states", {step = 5, metrics_type = ts_utils.metrics.gauge, is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("iowait_pct")
schema:addMetric("active_pct") -- sum of system + user
schema:addMetric("idle_pct") -- idle

schema = ts_utils.newSchema("system:cpu_load", {step = 5, metrics_type = ts_utils.metrics.gauge, rrd_fname="cpu_ld", is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("load_percentage")

-------------------------------------------------------
-- Timeseries write queue length
-------------------------------------------------------

schema = ts_utils.newSchema("iface:ts_queue_length", {step = 5, metrics_type = ts_utils.metrics.gauge, is_critical_ts = true})
schema:addTag("ifid")
schema:addMetric("num_ts") -- Number of timeseries currently in the queue

-------------------------------------------------------
-- FLOW CHECKS SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("flow_check:duration", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("check")
schema:addTag("subdir")
schema:addMetric("num_ms")

schema = ts_utils.newSchema("flow_check:num_calls", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("check")
schema:addTag("subdir") -- NOTE: needed by checks.ts_dump
schema:addMetric("num_calls")

schema = ts_utils.newSchema("flow_check:total_stats", {step = 5, metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("subdir") -- NOTE: needed by checks.ts_dump
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
