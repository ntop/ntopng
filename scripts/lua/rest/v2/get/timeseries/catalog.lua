--
-- (C) 2013-26 - ntop.org
--
-- Timeseries catalog endpoint.
-- Returns the list of available schemas for a given entity type (or all entities).
-- Response is epoch-independent and safe to cache for the whole session.
-- Replaces: type/consts.lua (which required sequential fetches per source type)
--
-- Examples:
--   GET /lua/rest/v2/get/timeseries/catalog.lua?entity=host&ifid=1
--   GET /lua/rest/v2/get/timeseries/catalog.lua?entity=iface&ifid=1
--   GET /lua/rest/v2/get/timeseries/catalog.lua               (all entities)
--
-- Response shape:
--   {
--     "host": [
--       {
--         "schema": "host:traffic",
--         "label": "Traffic RX/TX",
--         "description": "...",
--         "unit": "bps",
--         "tags_required": ["ifid","host"],
--         "metrics": [{"id":"bytes_sent","label":"Sent"},{"id":"bytes_rcvd","label":"Received","invert":true}]
--       }, ...
--     ],
--     "iface": [ ... ]
--   }
--


local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/handlers/?.lua;" .. package.path
if ntop.isPro and ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/timeseries/handlers/?.lua;" .. package.path
end

local rest_utils     = require("rest_utils")
local timeseries_info = require("timeseries_info")
local ts_utils       = require("ts_utils")
require "lua_utils_generic"

-- Extract tag names from a registered schema
local function get_tags_for_schema(schema_name)
    local schema = ts_utils.getSchema(schema_name)
    if not schema then return {} end
    local tags = {}
    for _, t in ipairs(schema._tags or {}) do
        tags[#tags + 1] = t
    end
    return tags
end

-- Serialize the metrics table from a handler entry
local function serialize_metrics(ts_entry_metrics)
    if not ts_entry_metrics then return {} end
    local out = {}
    for id, info in pairs(ts_entry_metrics) do
        local m = { id = id, label = info.label or id }
        if info.invert_direction then m.invert = true end
        if info.color            then m.color  = info.color end
        out[#out + 1] = m
    end
    return out
end

-- Convert a handler timeseries_list entry to the catalog entry format
local function to_catalog_entry(entry)
    local schema_name = entry.schema or ""
    return {
        schema      = schema_name,
        label       = entry.label or schema_name,
        description = entry.description or "",
        unit        = entry.measure_unit or "",
        tags_required = get_tags_for_schema(schema_name),
        metrics     = serialize_metrics(entry.timeseries),
        default_visible = entry.default_visible or false,
    }
end

-- entity map: query param value -> timeseries_id prefix used by timeseries_info

local entity_map = {
    iface            = "iface",
    host             = "host",
    mac              = "mac",
    network          = "subnet",
    subnet           = "subnet",
    asn              = "asn",
    country          = "country",
    os               = "os",
    vlan             = "vlan",
    host_pool        = "host_pool",
    pod              = "pod",
    container        = "container",
    hash_state       = "ht",
    system           = "system",
    profile          = "profile",
    redis            = "redis",
    influxdb         = "influxdb",
    active_monitoring = "am",
    snmp_interface   = "snmp_interface",
    snmp_device      = "snmp_device",
    observation_point = "obs_point",
    flow_dev         = "flowdev",
    flow_port        = "flowdev_port",
    sflow_dev        = "sflowdev",
    sflow_port       = "sflowdev_port",
    flow             = "flow",
    flow_aggr        = "flow_aggr",
}

-- build catalog
local ifid   = tostring(_GET["ifid"] or interface.getId())
local entity = _GET["entity"]   -- optional filter

if ifid then
    interface.select(ifid)
end

-- tags passed to getTimeseries so handlers can filter availability
local tags = { ifid = ifid }

local catalog = {}

local entities_to_query = {}
if entity and entity_map[entity] then
    entities_to_query[entity] = entity_map[entity]
else
    entities_to_query = entity_map
end

for entity_key, prefix in pairs(entities_to_query) do
    local ok, ts_list = pcall(timeseries_info.getTimeseries, tags, prefix)
    if ok and ts_list then
        local entries = {}
        for _, entry in ipairs(ts_list) do
            entries[#entries + 1] = to_catalog_entry(entry)
        end
        if #entries > 0 then
            catalog[entity_key] = entries
        end
    end
end

rest_utils.answer(rest_utils.consts.success.ok, catalog)
