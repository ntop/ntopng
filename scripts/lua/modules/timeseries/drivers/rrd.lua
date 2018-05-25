--
-- (C) 2018 - ntop.org
--

local driver = {}

local os_utils = require("os_utils")
local ts_types = require("ts_types")

-- TODO remove this dependency
require("graph_utils")

local RRD_CONSOLIDATION_FUNCTION = "AVERAGE"
local use_hwpredict = false

local type_to_rrdtype = {
  [ts_types.counter] = "DERIVE",
  [ts_types.gauge] = "GAUGE",
}

-- NOTE: to get the actual rentention period, multiply retention_dp * aggregation_dp * step
local supported_steps = {
  ["1"] = {
    rra = {
      {aggregation_dp = 1, retention_dp = 86400},   -- 1 second resolution: keep for 1 day
      {aggregation_dp = 60, retention_dp = 43200},  -- 1 minute resolution: keep for 1 month
      {aggregation_dp = 3600, retention_dp = 2400}, -- 1 hour resolution: keep for 100 days
    }, hwpredict = {
      row_count = 86400,  -- keep 1 day prediction
      period = 3600,      -- assume 1 hour periodicity
    }
  },
  ["60"] = {
    rra = {
      {aggregation_dp = 1, retention_dp = 1440},    -- 1 minute resolution: keep for 1 day
      {aggregation_dp = 60, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
      {aggregation_dp = 1440, retention_dp = 365},  -- 1 day resolution: keep for 1 year
    }, hwpredict = {
      row_count = 10080,  -- keep 1 week prediction
      period = 1440,      -- assume 1 day periodicity
    }
  },
  ["60_ext"] = {
    rra = {
      {aggregation_dp = 1, retention_dp = 43200},   -- 1 minute resolution: keep for 1 month
      {aggregation_dp = 60, retention_dp = 24000},  -- 1 hour resolution: keep for 100 days
      {aggregation_dp = 1440, retention_dp = 365},  -- 1 day resolution: keep for 1 year
    }, hwpredict = {
      row_count = 10080,  -- keep 1 week prediction
      period = 1440,      -- assume 1 day periodicity
    }
  },
  ["300"] = {
    rra = {
      {aggregation_dp = 1, retention_dp = 288},     -- 5 minute resolution: keep for 1 day
      {aggregation_dp = 12, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
      {aggregation_dp = 288, retention_dp = 365},   -- 1 day resolution: keep for 1 year
    }, hwpredict = {
      row_count = 2016,  -- keep 1 week prediction
      period = 288,      -- assume 1 day periodicity
    }
  },
  ["300_ext"] = {
    rra = {
      {aggregation_dp = 1, retention_dp = 8640},    -- 5 minutes resolution: keep for 1 month
      {aggregation_dp = 12, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
      {aggregation_dp = 288, retention_dp = 365},   -- 1 day resolution: keep for 1 year
    }, hwpredict = {
      row_count = 2016,  -- keep 1 week prediction
      period = 288,      -- assume 1 day periodicity
    }
  }
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

local function get_step_key(schema)
  local step_k = tostring(schema.options.step)

  if string.find(schema.name, "iface:tcp_") ~= nil then
    -- This is an extended counter
    step_k = step_k .. "_ext"
  end

  return step_k
end

local function create_rrd(schema, path)
  if not ntop.exists(path) then
    local heartbeat = schema.options.rrd_heartbeat or (schema.options.step * 2)
    local params = {path, schema.options.step}
    local supported_steps = supported_steps[get_step_key(schema)]

    local metrics_map = map_metrics_to_rrd_columns(schema)
    if not metrics_map then
      return false
    end

    for idx, metric in ipairs(schema._metrics) do
      local info = schema.metrics[metric]
      params[#params + 1] = "DS:" .. metrics_map[idx] .. ":" .. type_to_rrdtype[info.type] .. ':' .. heartbeat .. ':U:U'
    end

    for _, rra in ipairs(supported_steps.rra) do
      params[#params + 1] = "RRA:" .. RRD_CONSOLIDATION_FUNCTION .. ":0.5:" .. rra.aggregation_dp .. ":" .. rra.retention_dp
    end

    if use_hwpredict then
      -- NOTE: at most one RRA, otherwise rrd_update crashes.
      local hwpredict = supported_steps.hwpredict
      params[#params + 1] = "RRA:HWPREDICT:" .. hwpredict.row_count .. ":0.1:0.0035:" .. hwpredict.period
    end

    -- NOTE: this is either a bug with unpack or with Lua.cpp make_argv
    params[#params + 1] = ""

    ntop.rrd_create(unpack(params))
  end

  return true
end

-------------------------------------------------------

local function update_rrd(schema, rrdfile, timestamp, data)
  local params = {tolongint(timestamp), }

  for _, metric in ipairs(schema._metrics) do
    params[#params + 1] = tolongint(data[metric])
  end

  ntop.rrd_update(rrdfile, unpack(params))
end

-------------------------------------------------------

local function verify_schema_compatibility(schema)
  if not supported_steps[get_step_key(schema)] then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "unsupported step '" .. schema.options.step .. "' in schema " .. schema.name)
    return false
  end

  if schema.tags.ifid == nil then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "missing ifid tag in schema " .. schema.name)
    return false
  end

  return true
end

function driver:append(schema, timestamp, tags, metrics)
  if not verify_schema_compatibility(schema) then
    return false
  end

  local base, rrd = schema_get_path(schema, tags)
  local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  ntop.mkdir(base)
  create_rrd(schema, rrdfile)
  update_rrd(schema, rrdfile, timestamp, metrics)

  return true
end

-------------------------------------------------------

function driver:query(schema, tstart, tend, tags)
  tprint("TODO QUERY")
end

function driver:delete(schema, tags)
  tprint("TODO DELETE")
end

return driver
