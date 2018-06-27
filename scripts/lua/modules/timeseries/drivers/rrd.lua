--
-- (C) 2018 - ntop.org
--

local driver = {}

local os_utils = require("os_utils")
local ts_types = require("ts_types")
require("ntop_utils")
require("rrd_paths")

local RRD_CONSOLIDATION_FUNCTION = "AVERAGE"
local use_hwpredict = false

local type_to_rrdtype = {
  [ts_types.counter] = "DERIVE",
  [ts_types.gauge] = "GAUGE",
}

-------------------------------------------------------

function driver:new(options)
  local obj = {
    base_path = options.base_path,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-------------------------------------------------------

function driver:flush()
  return true
end

-------------------------------------------------------

-- TODO remove after migrating to the new path format
-- Maps second tag name to getRRDName
local HOST_PREFIX_MAP = {
  host = "",
  subnet = "net:",
  flowdev_port = "flow_device:",
  sflowdev_port = "sflow:",
  snmp_if = "snmp:",
  host_pool = "pool:",
}

local function get_fname_for_schema(schema, tags)
  if schema.options.rrd_fname ~= nil then
    return schema.options.rrd_fname
  end

  -- return the last defined tag
  return tags[schema._tags[#schema._tags]]
end

local function schema_get_path(schema, tags)
  local parts = {schema.name, }
  local suffix = ""
  local rrd

  -- ifid is mandatory here
  local ifid = tags.ifid
  local host_or_network = nil

  if string.find(schema.name, "iface:") == nil and string.find(schema.name, "mac:") == nil then
    local parts = split(schema.name, ":")
    host_or_network = (HOST_PREFIX_MAP[parts[1]] or (parts[1] .. ":")) .. tags[schema._tags[2]]

    if parts[1] == "snmp_if" then
      suffix = tags.if_index .. "/"
    elseif (parts[1] == "flowdev_port") or (parts[1] == "sflowdev_port") then
      suffix = tags.port .. "/"
    end
  end

  local path = getRRDName(ifid, host_or_network) .. suffix
  local rrd = get_fname_for_schema(schema, tags)

  return path, rrd
end

local function schema_get_full_path(schema, tags)
  local base, rrd = schema_get_path(schema, tags)
  local full_path = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  return full_path
end

-- TODO remove after migration
function find_schema(rrdFile, rrdfname, tags, ts_utils)
  -- try to guess additional tags
  local v = split(rrdfname, ".rrd")
  if #v == 2 then
    local app = v[1]

    if interface.getnDPIProtoId(app) ~= -1 then
      tags.protocol = app
    elseif interface.getnDPICategoryId(app) ~= -1 then
      tags.category = app
    end
  end

  for _, schema in pairs(ts_utils.getLoadedSchemas()) do
    -- verify tags compatibility
    for tag in pairs(schema.tags) do
      if tags[tag] == nil then
        goto next_schema
      end
    end

    local full_path = schema_get_full_path(schema, tags)

    if full_path == rrdFile then
      return schema
    end

    ::next_schema::
  end

  return nil
end

-------------------------------------------------------

local function getRRAParameters(step, resolution, retention_time)
  local aggregation_dp = math.ceil(resolution / step)
  local retention_dp = math.ceil(retention_time / resolution)
  return aggregation_dp, retention_dp
end

-- This is necessary to keep the current RRD format
local function map_metrics_to_rrd_columns(schema)
  local num = #schema._metrics

  if num == 1 then
    return {"num"}
  elseif num == 2 then
    return {"sent", "rcvd"}
  elseif num == 3 then
    return {"ingress", "egress", "inner"}
  end

  traceError(TRACE_ERROR, TRACE_CONSOLE, "unsupported number of metrics (" .. num .. ") in schema " .. schema.name)
  return nil
end

local function create_rrd(schema, path)
  local heartbeat = schema.options.rrd_heartbeat or (schema.options.step * 2)
  local params = {path, schema.options.step}

  local metrics_map = map_metrics_to_rrd_columns(schema)
  if not metrics_map then
    return false
  end

  for idx, metric in ipairs(schema._metrics) do
    local info = schema.metrics[metric]
    params[#params + 1] = "DS:" .. metrics_map[idx] .. ":" .. type_to_rrdtype[info.type] .. ':' .. heartbeat .. ':U:U'
  end

  for _, rra in ipairs(schema.retention) do
    params[#params + 1] = "RRA:" .. RRD_CONSOLIDATION_FUNCTION .. ":0.5:" .. rra.aggregation_dp .. ":" .. rra.retention_dp
  end

  if use_hwpredict then
    -- NOTE: at most one RRA, otherwise rrd_update crashes.
    local hwpredict = schema.hwpredict
    params[#params + 1] = "RRA:HWPREDICT:" .. hwpredict.row_count .. ":0.1:0.0035:" .. hwpredict.period
  end

  -- NOTE: this is either a bug with unpack or with Lua.cpp make_argv
  params[#params + 1] = ""

  ntop.rrd_create(table.unpack(params))

  return true
end

-------------------------------------------------------

local function update_rrd(schema, rrdfile, timestamp, data)
  local params = {tolongint(timestamp), }

  for _, metric in ipairs(schema._metrics) do
    params[#params + 1] = tolongint(data[metric])
  end

  ntop.rrd_update(rrdfile, table.unpack(params))
end

-------------------------------------------------------

function driver:append(schema, timestamp, tags, metrics)
  local base, rrd = schema_get_path(schema, tags)
  local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  if not ntop.exists(rrdfile) then
    ntop.mkdir(base)
    create_rrd(schema, rrdfile)
  end

  update_rrd(schema, rrdfile, timestamp, metrics)

  return true
end

-------------------------------------------------------

function driver:query(schema, tstart, tend, tags, options)
  local base, rrd = schema_get_path(schema, tags)
  local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  local fstart, fstep, fdata, fend, fcount = ntop.rrd_fetch_columns(rrdfile, RRD_CONSOLIDATION_FUNCTION, tstart, tend)
  local serie_idx = 1
  local series = {}

  for _, serie in pairs(fdata) do
    local name = schema._metrics[serie_idx]

    -- unify the format
    for i, v in pairs(serie) do
      if v ~= v then
        -- NaN value
        v = options.fill_value
      elseif v < options.min_value then
        v = options.min_value
      elseif v > options.max_value then
        v = options.max_value
      end

      serie[i] = v
    end

    -- Remove the last value: RRD seems to give an additional point
    serie[#serie] = nil
    series[serie_idx] = {label=name, data=serie}

    serie_idx = serie_idx + 1
  end

  return {
    start = fstart,
    step = fstep,
    count = fcount,
    series = series
  }
end

-------------------------------------------------------

-- *Limitation*
-- tags_filter is expected to contain all the tags of the schema except the last
-- one. For such tag, a list of available values will be returned.
function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
  if #wildcard_tags > 1 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver does not support listSeries on multiple tags")
    return nil
  end

  local wildcard_tag = wildcard_tags[1]

  if not wildcard_tag then
    local full_path = schema_get_full_path(schema, tags_filter)
    local last_update = ntop.rrd_lastupdate(full_path)

    if last_update ~= nil and last_update >= start_time then
      return {tags_filter}
    else
      return {}
    end
  end

  if wildcard_tag ~= schema._tags[#schema._tags] then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver only support listSeries with wildcard in the last tag, got wildcard on '" .. wildcard_tag .. "'")
    return nil
  end

  local base, rrd = schema_get_path(schema, table.merge(tags_filter, {[wildcard_tag] = ""}))
  local files = ntop.readdir(base)
  local res = {}

  for f in pairs(files or {}) do
    local v = split(f, ".rrd")

    if #v == 2 then
      local fpath = base .. "/" .. f
      local last_update = ntop.rrd_lastupdate(fpath)

      if last_update ~= nil and last_update >= start_time then
        res[#res + 1] = table.merge(tags_filter, {[wildcard_tag] = v[1]})
      end
    end
  end

  return res
end

-------------------------------------------------------

function driver:delete(schema, tags)
  tprint("TODO DELETE")
end

-------------------------------------------------------

return driver
