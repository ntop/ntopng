--
-- (C) 2013-18 - ntop.org
--

--
-- Example of REST call
-- 
-- curl -u admin:admin -X POST -d '{"ts_schema":"host:traffic", "ts_query": "ifid:3,host:192.168.1.98", "epoch_begin": "1532180495", "epoch_end": "1548839346"}' -H "Content-Type: application/json" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua"
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local nv_graph_utils

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  nv_graph_utils = require "nv_graph_utils"
end

require "lua_utils"
require "graph_utils"
local ts_utils = require("ts_utils")
local ts_common = require("ts_common")
local json = require("dkjson")

local ts_schema = _GET["ts_schema"]
local query     = _GET["ts_query"]
local tstart    = _GET["epoch_begin"]
local tend      = _GET["epoch_end"]
local compare_backward = _GET["ts_compare"]
local tags      = _GET["ts_query"]
local extended_times  = _GET["extended"]
local ts_aggregation  = _GET["ts_aggregation"]

if _POST["payload"] ~= nil then
  -- REST request, use extended mode
  extended_times = true
end

tstart = tonumber(tstart) or (os.time() - 3600)
tend = tonumber(tend) or os.time()
tags = tsQueryToTags(tags)

local driver = ts_utils.getQueryDriver()
local latest_tstamp = driver:getLatestTimestamp(tags.ifid or -1)

local options = {
  max_num_points = tonumber(_GET["limit"]),
  initial_point = toboolean(_GET["initial_point"]),
  no_timeout = true,
  with_series = true,
  target_aggregation = ts_aggregation,
}

-- Check end time bound and realign if necessary
if (tend > latest_tstamp) and ((tend - latest_tstamp) <= ts_utils.MAX_EXPORT_TIME) then
  local delta = tend - latest_tstamp
  local alignment = (tend - tstart) / options.max_num_points

  delta = delta + (alignment - delta % alignment)
  tend = math.floor(tend - delta)
  tstart = math.floor(tstart - delta)
end

if tags.ifid then
  interface.select(tags.ifid)
end

sendHTTPHeader('application/json')

local function performQuery(tstart, tend, keep_total, additional_options)
  local res
  additional_options = additional_options or {}
  local options = table.merge(options, additional_options)

  if starts(ts_schema, "top:") then
    local ts_schema = split(ts_schema, "top:")[2]

    res = ts_utils.queryTopk(ts_schema, tags, tstart, tend, options)
  else
    res = ts_utils.query(ts_schema, tags, tstart, tend, options)

    if(not keep_total) and (res) and (res.additional_series) then
      -- no need for total serie in normal queries
      res.additional_series.total = nil
    end
  end

  return res
end

local res

if starts(ts_schema, "custom:") and ntop.isPro() then
  res = performCustomQuery(ts_schema, tags, tstart, tend, options)
  compare_backward = nil
else
  res = performQuery(tstart, tend)
end

if res == nil then
  res = {}

  if(ts_utils.getLastError() ~= nil) then
    res["tsLastError"] = ts_utils.getLastError()
    res["error"] = ts_utils.getLastErrorMessage()
  end

  print(json.encode(res))
  return
end

-- Add metadata
res.schema = ts_schema
res.query = tags
res.max_points = options.max_num_points

if not isEmptyString(compare_backward) and compare_backward ~= "1Y" then
  local backward_sec = getZoomDuration(compare_backward)
  local tstart_cmp = tstart - backward_sec
  local tend_cmp = tend - backward_sec

  -- Try to use the same aggregation as the original query
  local res_cmp = performQuery(tstart_cmp, tend_cmp, true, {target_aggregation=res.source_aggregation})
  local total_cmp_serie = nil

  if res_cmp and res_cmp.additional_series and res_cmp.additional_series.total and res_cmp.step >= res.step then
    total_cmp_serie = res_cmp.additional_series.total

    if res_cmp.step > res.step then
      -- The steps may not still correspond if the past query overlaps a retention policy
      -- bound (it will have less points, but with an higher step), upscale to solve this
      total_cmp_serie = ts_common.upsampleSerie(total_cmp_serie, res.count)
    end
  end

  if total_cmp_serie then
    res.additional_series = res.additional_series or {}
    res.additional_series[compare_backward.. " " ..i18n("details.ago")] = total_cmp_serie
  end
end

-- TODO make a script parameter?
local extend_labels = true

if extend_labels and ntop.isPro() then
  extendLabels(res)
end

if extended_times then
  if res.series then
    for k, serie in pairs(res.series) do
      serie.data = ts_common.serieWithTimestamp(serie.data, tstart, res.step)
    end
  end
  if res.additional_series then
    for k, serie in pairs(res.additional_series) do
      res.additional_series[k] = ts_common.serieWithTimestamp(serie, tstart, res.step)
    end
  end
end

print(json.encode(res))
