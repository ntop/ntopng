--
-- (C) 2013-26 - ntop.org
--
-- Schema introspection endpoint for AI agents and tooling.
-- Given a schema name, returns what tags are required, what metrics it measures,
-- and its timing parameters.  Designed to be called with minimal context.
--
-- Example:
--   GET /lua/rest/v2/get/timeseries/schema_info.lua?schema=host:traffic
--
-- Response:
--   {
--     "schema": "host:traffic",
--     "entity": "host",
--     "tags_required": ["ifid", "host"],
--     "metrics": ["bytes_sent", "bytes_rcvd"],
--     "step": 300,
--     "unit": "bps",
--     "description": "Bytes sent and received per host",
--     "example_query": "curl ... -d '{\"queries\":[{\"id\":\"q0\",\"ts_schema\":\"host:traffic\",\"ts_query\":\"ifid:1,host:192.168.1.1\"}],...}'"
--   }
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local ts_utils   = require("ts_utils")
require "lua_utils_generic"

local schema_name = _GET["schema"]

if isEmptyString(schema_name) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

local schema = ts_utils.getSchema(schema_name)

if not schema then
    rest_utils.answer(rest_utils.consts.err.not_found)
    return
end

-- Derive entity from the schema name prefix (e.g. "host:traffic" → "host")
local entity = schema_name:match("^([^:]+)") or ""

-- Tags
local tags = {}
for _, t in ipairs(schema._tags or {}) do
    tags[#tags + 1] = t
end

-- Metrics
local metrics = {}
for _, m in ipairs(schema._metrics or {}) do
    metrics[#metrics + 1] = m
end

-- Build a ts_query example from the tags
local example_tags = {}
for _, t in ipairs(tags) do
    if t == "ifid" then
        example_tags[#example_tags + 1] = "ifid:1"
    elseif t == "host" then
        example_tags[#example_tags + 1] = "host:192.168.1.1"
    else
        example_tags[#example_tags + 1] = t .. ":VALUE"
    end
end
local example_ts_query = table.concat(example_tags, ",")

local result = {
    schema        = schema_name,
    entity        = entity,
    tags_required = tags,
    metrics       = metrics,
    step          = schema.options and schema.options.step or 300,
    example_query = {
        endpoint   = "/lua/rest/v2/get/timeseries/batch.lua",
        method     = "POST",
        body = {
            epoch_begin = os.time() - 3600,
            epoch_end   = os.time(),
            queries     = {{
                id       = "q0",
                ts_schema = schema_name,
                ts_query  = example_ts_query,
            }},
        },
    },
}

rest_utils.answer(rest_utils.consts.success.ok, result)
