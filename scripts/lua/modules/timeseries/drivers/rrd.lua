--
-- (C) 2018 - ntop.org
--

local driver = {}

local os_utils = require("os_utils")
local ts_common = require("ts_common")
require("ntop_utils")
require("rrd_paths")

local RRD_CONSOLIDATION_FUNCTION = "AVERAGE"
local use_hwpredict = false

local type_to_rrdtype = {
  [ts_common.metrics.counter] = "DERIVE",
  [ts_common.metrics.gauge] = "GAUGE",
}

-- ##############################################

function driver:new(options)
  local obj = {
    base_path = options.base_path,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-- ##############################################

function driver:export()
  return
end

-- ##############################################

function driver:getLatestTimestamp(ifid)
  return os.time()
end

-- ##############################################

-- TODO remove after migrating to the new path format
-- Maps second tag name to getRRDName
local HOST_PREFIX_MAP = {
  host = "",
  mac = "",
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

  if string.find(schema.name, "iface:") == nil then
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

  for schema_name, schema in pairs(ts_utils.getLoadedSchemas()) do
    -- verify tags compatibility
    for tag in pairs(schema.tags) do
      if tags[tag] == nil then
        goto next_schema
      end
    end

    local full_path = schema_get_full_path(schema, tags)

    if full_path == rrdFile then
      return schema_name
    end

    ::next_schema::
  end

  return nil
end

-- ##############################################

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

-- This is necessary to keep the current RRD format
local function map_rrd_column_to_metrics(schema, column_name)
   if (column_name == "num") or starts(column_name, "num_")
      or (column_name == "drops") or starts(column_name, "tcp_")
      or (column_name == "sent") or (column_name == "ingress")
      or (column_name == "bytes") or (column_name == "packets")
   then
    return 1
  elseif (column_name == "rcvd") or (column_name == "egress") then
    return 2
  elseif (column_name == "inner") then
    return 3
  end

  traceError(TRACE_ERROR, TRACE_CONSOLE, "unknown column name (" .. column_name .. ") in schema " .. schema.name)
  return nil
end

local function create_rrd(schema, path)
  local heartbeat = schema.options.rrd_heartbeat or (schema.options.step * 2)
  local rrd_type = type_to_rrdtype[schema.options.metrics_type]
  local params = {path, schema.options.step}

  local metrics_map = map_metrics_to_rrd_columns(schema)
  if not metrics_map then
    return false
  end

  for idx, metric in ipairs(schema._metrics) do
    params[#params + 1] = "DS:" .. metrics_map[idx] .. ":" .. rrd_type .. ':' .. heartbeat .. ':U:U'
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

-- ##############################################

local function update_rrd(schema, rrdfile, timestamp, data)
  local params = {tolongint(timestamp), }

  for _, metric in ipairs(schema._metrics) do
    params[#params + 1] = tolongint(data[metric])
  end

  ntop.rrd_update(rrdfile, table.unpack(params))
end

-- ##############################################

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

-- ##############################################

local function makeTotalSerie(series, count)
  local total = {}

  for i=1,count do
    total[i] = 0
  end

  for _, serie in pairs(series) do
    for i, val in pairs(serie.data) do
      total[i] = total[i] + val
    end
  end

  return total
end

-- ##############################################

local function sampleSeries(schema, cur_points, step, max_points, series)
  local sampled_dp = math.ceil(cur_points / max_points)
  local count = nil

  for _, data_serie in pairs(series) do
    local serie = data_serie.data
    local num = 0
    local sum = 0
    local end_idx = 1

    for _, dp in ipairs(serie) do
      sum = sum + dp
      num = num + 1

      if num == sampled_dp then
        -- A data group is ready
        serie[end_idx] = sum / num
        end_idx = end_idx + 1

        num = 0
        sum = 0
      end
    end

    -- Last group
    if num > 0 then
      serie[end_idx] = sum / num
      end_idx = end_idx + 1
    end

    count = end_idx-1

    -- remove the exceeding points
    for i = end_idx, #serie do
      serie[i] = nil
    end
  end

  -- new step, new count, new data
  return step * sampled_dp, count, series
end

-- ##############################################

-- Make sure we do not fetch data from RRDs that have been update too much long ago
-- as this creates issues with the consolidation functions when we want to compare
-- results coming from different RRDs.
-- This is also needed to make sure that multiple data series on graphs have the
-- same number of points, otherwise d3js will generate errors.
local function touchRRD(rrdname)
  local now  = os.time()
  local last, ds_count = ntop.rrd_lastupdate(rrdname)

  if((last ~= nil) and ((now-last) > 3600)) then
    local tdiff = now - 1800 -- This avoids to set the update continuously

    if(ds_count == 1) then
      ntop.rrd_update(rrdname, tdiff.."", "0")
    elseif(ds_count == 2) then
      ntop.rrd_update(rrdname, tdiff.."", "0", "0")
    elseif(ds_count == 3) then
      ntop.rrd_update(rrdname, tdiff.."", "0", "0", "0")
    end
  end
end

-- ##############################################

function driver:query(schema, tstart, tend, tags, options)
  local base, rrd = schema_get_path(schema, tags)
  local rrdfile = os_utils.fixPath(base .. "/" .. rrd .. ".rrd")

  if not ntop.exists(rrdfile) then
     return nil
  end

  touchRRD(rrdfile)

  --tprint("rrdtool fetch ".. rrdfile.. " " .. RRD_CONSOLIDATION_FUNCTION .. " -s ".. tstart .. " -e " .. tend)
  local fstart, fstep, fdata, fend, fcount = ntop.rrd_fetch_columns(rrdfile, RRD_CONSOLIDATION_FUNCTION, tstart, tend)

  local count = 0
  local series = {}

  for name_key, serie in pairs(fdata or {}) do
    local serie_idx = map_rrd_column_to_metrics(schema, name_key)
    local name = schema._metrics[serie_idx]
    local max_val = ts_common.getMaxPointValue(schema, name, tags)
    count = 0

    -- unify the format
    for i, v in pairs(serie) do
      local v = ts_common.normalizeVal(v, max_val, options)
      serie[i] = v
      count = count + 1
    end

    -- Remove the last value: RRD seems to give an additional point
    serie[#serie] = nil
    count = count - 1

    series[serie_idx] = {label=name, data=serie}

    serie_idx = serie_idx + 1
  end

  if count > options.max_num_points then
    fstep, count, series = sampleSeries(schema, count, fstep, options.max_num_points, series)
  end

  --local returned_tend = fstart + fstep * (count-1)
  --tprint(returned_tend .. " " .. fstart)

  local total_serie = nil
  local stats = nil

  if options.calculate_stats then
    total_serie = makeTotalSerie(series, count)
    stats = ts_common.calculateStatistics(total_serie, fstep, tend - tstart, schema.options.metrics_type)
  end

  if options.initial_point then
    local _, _, initial_pt = ntop.rrd_fetch_columns(rrdfile, RRD_CONSOLIDATION_FUNCTION, tstart-schema.options.step, tstart-schema.options.step)
    initial_pt = initial_pt or {}

    for name_key, values in pairs(initial_pt) do
      local serie_idx = map_rrd_column_to_metrics(schema, name_key)
      local name = schema._metrics[serie_idx]
      local max_val = ts_common.getMaxPointValue(schema, name, tags)
      local ptval = ts_common.normalizeVal(values[1], max_val, options)

      table.insert(series[serie_idx].data, 1, ptval)
    end

    count = count + 1

    if total_serie then
      -- recalculate with additional point
      total_serie = makeTotalSerie(series, count)
    end
  end

  if options.calculate_stats then
    stats = table.merge(stats, ts_common.calculateMinMax(total_serie))
  end

  return {
    start = fstart,
    step = fstep,
    count = count,
    series = series,
    statistics = stats,
    additional_series = {
      total = total_serie,
    },
  }
end

-- ##############################################

-- *Limitation*
-- tags_filter is expected to contain all the tags of the schema except the last
-- one. For such tag, a list of available values will be returned.
local function _listSeries(schema, tags_filter, wildcard_tags, start_time, with_l4)
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

  -- TODO remove after migration
  local l4_keys = {tcp=1, udp=1, icmp=1}

  local base, rrd = schema_get_path(schema, table.merge(tags_filter, {[wildcard_tag] = ""}))
  local files = ntop.readdir(base)
  local res = {}

  for f in pairs(files or {}) do
    local v = split(f, ".rrd")
    local fpath = base .. "/" .. f

    if #v == 2 then
      local last_update = ntop.rrd_lastupdate(fpath)

      if last_update ~= nil and last_update >= start_time then
        -- TODO remove after migration
        local value = v[1]

        if ((wildcard_tag ~= "protocol") or (with_l4 and l4_keys[value] ~= nil) or (interface.getnDPIProtoId(value) ~= -1)) and
            ((wildcard_tag ~= "category") or (interface.getnDPICategoryId(value) ~= -1)) then
          res[#res + 1] = table.merge(tags_filter, {[wildcard_tag] = value})
        end
      end
    elseif ntop.isdir(fpath) then
      fpath = fpath .. "/" .. rrd .. ".rrd"

      local last_update = ntop.rrd_lastupdate(fpath)

      if last_update ~= nil and last_update >= start_time then
        res[#res + 1] = table.merge(tags_filter, {[wildcard_tag] = f})
      end
    end
  end

  return res
end

-- ##############################################

function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
  return _listSeries(schema, tags_filter, wildcard_tags, start_time, true --[[ with l4 protos ]])
end

-- ##############################################

function driver:topk(schema, tags, tstart, tend, options, top_tags)
  if #top_tags > 1 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver does not support topk on multiple tags")
    return nil
  end

  local top_tag = top_tags[1]

  if top_tag ~= schema._tags[#schema._tags] then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "RRD driver only support topk with topk tag in the last tag, got topk on '" .. (top_tag or "") .. "'")
    return nil
  end

  local series = _listSeries(schema, tags, top_tags, tstart, false --[[ no l4 protos ]])
  if not series then
    return nil
  end

  local items = {}
  local tag_2_series = {}
  local total_serie = {}
  local total_valid = true
  local step = 0
  local query_start = tstart

  if options.initial_point then
    query_start =  tstart - schema.options.step
  end

  for _, serie_tags in pairs(series) do
    local rrdfile = schema_get_full_path(schema, serie_tags)
    touchRRD(rrdfile)

    local fstart, fstep, fdata, fend, fcount = ntop.rrd_fetch_columns(rrdfile, RRD_CONSOLIDATION_FUNCTION, query_start, tend)
    local sum = 0
    step = fstep

    for name_key, serie in pairs(fdata) do
      local serie_idx = map_rrd_column_to_metrics(schema, name_key)
      local name = schema._metrics[serie_idx]
      local max_val = ts_common.getMaxPointValue(schema, name, serie_tags)

      if (#total_serie ~= 0) and #total_serie ~= #serie then
        -- NOTE: even if touchRRD is used, series can still have a different number
        -- of points when the tend parameter does not correspond to the current time
        -- e.g. when comparing with the past or manually zooming.
        -- In this case, total serie il discarded as it's incorrect
        total_valid = false
      end

      for i=#total_serie + 1, #serie do
        -- init
        total_serie[i] = 0
      end

      for i, v in pairs(serie) do
        local v = ts_common.normalizeVal(v, max_val, options)

        if type(v) == "number" then
          sum = sum + v
          total_serie[i] = total_serie[i] + v
        end
      end
    end

    items[serie_tags[top_tag]] = sum
    tag_2_series[serie_tags[top_tag]] = serie_tags
  end

  local topk = {}

  for top_item, value in pairsByValues(items, rev) do
    topk[#topk + 1] = {
      tags = tag_2_series[top_item],
      value = value,
    }

    if #topk >= options.top then
      break
    end
  end

  local stats = nil

  -- Remove the last value: RRD seems to give an additional point
  total_serie[#total_serie] = nil

  local augumented_total = total_serie

  if options.initial_point and total_serie then
    augumented_total = table.clone(total_serie)
    table.remove(total_serie, 1)
  end

  local fstep, count, augumented_total = sampleSeries(schema, #augumented_total, step, options.max_num_points, {{data=augumented_total}})
  augumented_total = augumented_total[1].data

  if options.calculate_stats then
    stats = ts_common.calculateStatistics(total_serie, step, tend - tstart, schema.options.metrics_type)
    stats = table.merge(stats, ts_common.calculateMinMax(augumented_total))
  end

  if not total_valid then
    total_serie = nil
    augumented_total = nil
  end

  return {
    topk = topk,
    additional_series = {
      total = augumented_total,
    },
    statistics = stats,
  }
end

-- ##############################################

function driver:delete(schema, tags)
  tprint("TODO DELETE")
end

-- ##############################################

return driver
