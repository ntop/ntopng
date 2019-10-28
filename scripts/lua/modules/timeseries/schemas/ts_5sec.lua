--
-- (C) 2019 - ntop.org
--

local ts_utils = require "ts_utils_core"
local schema

-------------------------------------------------------
-- HASH_TABLES SCHEMAS
-------------------------------------------------------

schema = ts_utils.newSchema("ht:lua_calls", {step = 5, rrd_fname="ht_lua_calls", metrics_type = ts_utils.metrics.gauge})
schema:addTag("ifid")
schema:addTag("hash_table")
schema:addMetric("num_ms")
schema:addMetric("num_calls")
