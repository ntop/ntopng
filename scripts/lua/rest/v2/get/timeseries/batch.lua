--
-- (C) 2013-26 - ntop.org
--
-- Unified timeseries batch endpoint.
-- Replaces: ts.lua, ts_multi.lua (pro)
-- Accepts N queries in one POST, returns all results + metadata in one response.
-- No serial waterfall: each query is independently pcall'd so one bad schema
-- does not kill the entire response.
--
-- Example:
--   curl -u admin:admin -X POST \
--     -H "Content-Type: application/json" \
--     -d '{"epoch_begin":1780294885,"epoch_end":1780381285,
--           "queries":[
--             {"id":"q0","ts_schema":"iface:traffic","ts_query":"ifid:1"},
--             {"id":"q1","ts_schema":"host:traffic","ts_query":"ifid:1,host:192.168.1.1"}
--           ]}' \
--     http://localhost:3000/lua/rest/v2/get/timeseries/batch.lua
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/handlers/?.lua;" .. package.path
if ntop.isPro and ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/timeseries/handlers/?.lua;" .. package.path
end

local rest_utils = require("rest_utils")
local ts_data    = require("ts_data")
local json       = require("dkjson")
require "lua_utils_generic"

local function get_date_format()
    local key
    if _SESSION then
        key = ntop.getPref("ntopng.user." .. (_SESSION["user"] or "") .. ".date_format")
    end
    if key == "big_endian" then
        return "YYYY/MM/DD HH:mm:ss"
    elseif key == "middle_endian" then
        return "MM/DD/YYYY HH:mm:ss"
    else
        return "DD/MM/YYYY HH:mm:ss"
    end
end

-- Build a schema_name -> measure_unit cache by loading only the relevant
-- handler module for a given schema prefix (lazy, memoised per request).
local _unit_cache = {}
local _handler_cache = {}

-- Schema prefix -> handler module name (handler files use different names)
local _prefix_to_module = {
    -- community handlers
    iface          = "ts_interface",
    host           = "ts_host",
    asn            = "ts_asn",
    mac            = "ts_mac",
    subnet         = "ts_network",
    country        = "ts_country",
    os             = "ts_os",
    vlan           = "ts_vlan",
    host_pool      = "ts_host_pool",
    pod            = "ts_pod",
    container      = "ts_container",
    ht             = "ts_hash_state",
    system         = "ts_system",
    profile        = "ts_profile",
    redis          = "ts_redis",
    influxdb       = "ts_influxdb",
    am             = "ts_active_monitoring",
    am_host        = "ts_active_monitoring",
    flow           = "ts_flow",
    flow_aggr      = "ts_flow_aggr",
    -- pro handlers
    flowdev        = "ts_flow_device",
    flowdev_port   = "ts_flow_device_port",
    sflowdev       = "ts_sflow_device",
    sflowdev_port  = "ts_sflow_device_port",
    snmp_device    = "ts_snmp_device",
    snmp_if        = "ts_snmp_interface",
    obs_point      = "ts_observation_point",
    nedge          = "ts_nedge",
}

local function get_handler_module(prefix)
    if _handler_cache[prefix] ~= nil then return _handler_cache[prefix] end
    local mod_name = _prefix_to_module[prefix] or ("ts_" .. prefix)
    local ok, mod = pcall(require, mod_name)
    _handler_cache[prefix] = ok and mod or false
    return _handler_cache[prefix]
end

-- Cache for schema -> { measure_unit, series_meta }
local _schema_cache = {}

local function get_schema_info(schema_name)
    if _schema_cache[schema_name] ~= nil then return _schema_cache[schema_name] end
    if schema_name == "top:iface:ndpi" then
      schema_name = "top:" .. getIfacenDPITsName()
    end

    local base_schema = schema_name:gsub("^top:", "")
    local prefix = base_schema:match("^([^:]+):")

    local info = { measure_unit = "number", series_meta = {} }

    if prefix then
        local mod = get_handler_module(prefix)
        if mod and mod.getTimeseries then
            local ok, ts_list = pcall(mod.getTimeseries, {}, { emptyEpoch = true })
            if ok and ts_list then
                for _, entry in ipairs(ts_list) do
                    if entry.schema == schema_name then
                        info.measure_unit = entry.measure_unit or "number"
                        -- Build per-series label + invert_direction map
                        if type(entry.timeseries) == "table" then
                            for series_id, smeta in pairs(entry.timeseries) do
                                info.series_meta[series_id] = {
                                    label            = smeta.label or series_id,
                                    invert_direction = smeta.invert_direction or false,
                                    color            = smeta.color,
                                }
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    _schema_cache[schema_name] = info
    return info
end

local function get_measure_unit(schema_name)
    return get_schema_info(schema_name).measure_unit
end

-- Parse the raw JSON payload directly to recover the queries array and any
-- other fields that http_lint may have stringified.

local payload = _POST["payload"]
local body = {}
if payload and payload ~= "" then
    body = json.decode(payload) or {}
end

local epoch_begin = tonumber(body["epoch_begin"] or _POST["epoch_begin"]) or (os.time() - 3600)
local epoch_end   = tonumber(body["epoch_end"]   or _POST["epoch_end"])   or  os.time()
local queries     = body["queries"]    -- JSON array, preserved from raw payload
local ts_compare  = body["ts_compare"] or _POST["ts_compare"]
local zoom        = body["zoom"]       or _POST["zoom"]
local limit       = tonumber(body["limit"] or _POST["limit"]) or 180
local version     = tostring(body["version"] or _POST["version"] or "4")

-- meta block (returned once, not per chart)

local meta = {
    epoch_begin = epoch_begin,
    epoch_end   = epoch_end,
    date_format = get_date_format(),
}

-- process queries
local results = {}

if queries and type(queries) == "table" then
    for _, q in ipairs(queries) do
        local qid = tostring(q.id or "")
        if isEmptyString(qid) then
            goto next_query
        end

        local schema_name = tostring(q.ts_schema or "")
        local tags = tsQueryToTags(tostring(q.ts_query or ""))

        -- Select the correct interface so RRD paths resolve
        if tags.ifid then
            interface.select(tostring(tags.ifid))
        end

        local http_context = {
            ts_schema     = schema_name,
            epoch_begin   = tostring(epoch_begin),
            epoch_end     = tostring(epoch_end),
            tags          = tags,
            ts_compare    = q.compare or ts_compare,
            zoom          = q.zoom    or zoom,
            limit         = tostring(q.limit or limit),
            version       = version,
            initial_point = tostring(q.initial_point or false),
        }

        if q.tskey ~= nil then
            http_context.tskey = tostring(q.tskey)
        end
        if q.ts_unify ~= nil then
            http_context.ts_unify = tostring(q.ts_unify)
        end

        local ok, res = pcall(ts_data.get_timeseries, http_context)
        if ok then
            res.error = nil
            -- ts_data may resolve schema aliases (e.g. top:iface:ndpi -> top:iface:ndpi_full).
            -- Re-attach the top: prefix so the handler lookup finds the right entry.
            local resolved_schema = schema_name
            if res.metadata and res.metadata.schema then
                local ms = res.metadata.schema
                if schema_name:sub(1, 4) == "top:" and ms:sub(1, 4) ~= "top:" then
                    resolved_schema = "top:" .. ms
                else
                    resolved_schema = ms
                end
            end
            local schema_info = get_schema_info(resolved_schema)
            res.measure_unit = schema_info.measure_unit
            -- Annotate each series with label + invert_direction from handler definition
            if type(res.series) == "table" then
                for _, serie in ipairs(res.series) do
                    local smeta = schema_info.series_meta[serie.id]
                    if smeta then
                        serie.label            = smeta.label
                        serie.invert_direction = smeta.invert_direction
                        if smeta.color then
                            serie.color = smeta.color
                        end
                    end
                end
            end
            results[qid] = res
        else
            results[qid] = {
                series       = {},
                metadata     = {},
                measure_unit = "number",
                error        = tostring(res),
            }
        end

        ::next_query::
    end
end

rest_utils.answer(rest_utils.consts.success.ok, {
    meta    = meta,
    results = results,
})
