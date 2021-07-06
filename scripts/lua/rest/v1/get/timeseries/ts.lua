--
-- (C) 2013-21 - ntop.org
--

--
-- Example of REST call
-- 
-- curl -u admin:admin -X POST -d '{"ts_schema":"host:traffic", "ts_query": "ifid:3,host:192.168.1.98", "epoch_begin": "1532180495", "epoch_end": "1548839346"}' -H "Content-Type: application/json" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua"
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local graph_common = require "graph_common"
local graph_utils = require "graph_utils"
local ts_utils = require("ts_utils")
local ts_common = require("ts_common")
local json = require("dkjson")
local rest_utils = require("rest_utils")

local ts_schema = _GET["ts_schema"]
local query     = _GET["ts_query"]
local tstart    = _GET["epoch_begin"]
local tend      = _GET["epoch_end"]
local compare_backward = _GET["ts_compare"]
local tags      = _GET["ts_query"]
local extended_times  = _GET["extended"]
local ts_aggregation  = _GET["ts_aggregation"]
local no_fill = tonumber(_GET["no_fill"])

-- Epochs in _GET are assumed to be adjusted to UTC. This is always the case when the browser submits epoch using a
-- datetimepicker (e.g., from any chart page).

-- This is what happens for example when drawing a chart from firefox set on three different timezones

-- TZ=UTC firefox.        12 May 2020 11:00:00 -> 1589281200 (sent by browser in _GET)
-- TZ=Europe/Rome.        12 May 2020 11:00:00 -> 1589274000 (sent by browser in _GET)
-- TZ=America/Sao_Paulo   12 May 2020 11:00:00 -> 1589292000 (sent by browser in _GET)

-- Basically, timestamps are adjusted to UTC before being sent in _GET:

-- - 1589274000 (Rome) - 1589281200 (UTC) = -7200: As Rome (CEST) is at +2 from UTC, then UTC is 2 hours ahead Rome
--   - 12 May 2020 11:00:00 in Rome (UTC) is 12 May 2020 09:00:00 UTC (-2)
-- - 1589292000 (Sao Paulo) - 1589281200 (UTC) = +10800: As Sao Paulo is at -3 from UTC, then UTC is 3 hours after UTC
--    - 12 May 2020 11:00:00 in Sao Paolo is 12 May 2020 14:00:00 UTC (+3)

-- As timeseries epochs are always written adjusted to UTC, there is no need to do any extra processing to the received epochs.
-- They are valid from any timezone, provided they are sent in the _GET as UTC adjusted.

tstart = tonumber(tstart) or (os.time() - 3600)
tend = tonumber(tend) or os.time()
tags = tsQueryToTags(tags)

if _GET["tskey"] then
  -- This can contain a MAC address for local broadcast domain hosts
  local tskey = _GET["tskey"]

  -- Setting host_ip (check that the provided IP matches the provided
  -- mac address as safety check and to avoid security issues)
  if tags.host then
    local host = hostkey2hostinfo(tags.host)
    if not isEmptyString(host["host"]) then
      local host_info = interface.getHostInfo(host["host"], host["vlan"])
      local mac_info = split(tskey, "_")
      if host_info.mac == mac_info[1] then
         tags.host_ip = tags.host;
      end
    end
  end

  tags.host = tskey
end

local driver = ts_utils.getQueryDriver()

local options = {
  max_num_points = tonumber(_GET["limit"]) or 60,
  initial_point = toboolean(_GET["initial_point"]),
  with_series = true,
  target_aggregation = ts_aggregation,
}

if(no_fill == 1) then
  options.fill_value = 0/0 -- NaN
end

-- Not necessary anymore as the influxdb driver:query method uses the
-- series last timestamp to avoid going in the future
--[[
-- Check end time bound and realign if necessary
local latest_tstamp = driver:getLatestTimestamp(tags.ifid or -1)

if (tend > latest_tstamp) and ((tend - latest_tstamp) <= ts_utils.MAX_EXPORT_TIME) then
  local delta = tend - latest_tstamp
  local alignment = (tend - tstart) / options.max_num_points

  delta = delta + (alignment - delta % alignment)
  tend = math.floor(tend - delta)
  tstart = math.floor(tstart - delta)
end
]]

if tags.ifid then
  interface.select(tags.ifid)
end

if((ts_schema == "top:flow_check:duration")
    or (ts_schema == "top:elem_check:duration")
    or (ts_schema == "custom:flow_check:total_stats")
    or (ts_schema == "custom:elem_check:total_stats")) then
  -- NOTE: Temporary fix for top checks page
  tags.check = nil
end

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

if(ntop.getPref("ntopng.prefs.ndpi_flows_rrd_creation") == "1") then
  if(ts_schema == "host:ndpi") then
    ts_schema = "custom:host_ndpi_and_flows"
  elseif(ts_schema == "iface:ndpi") then
    ts_schema = "custom:iface_ndpi_and_flows"
  end
end

if starts(ts_schema, "custom:") and graph_utils.performCustomQuery then
  res = graph_utils.performCustomQuery(ts_schema, tags, tstart, tend, options)
  compare_backward = nil
else
  res = performQuery(tstart, tend)
end

if res == nil then
   res = {}

   if(ts_utils.getLastError() ~= nil) then
      res["tsLastError"] = ts_utils.getLastError()
      res["error"] = ts_utils.getLastErrorMessage()
      rest_utils.answer(rest_utils.consts.err.internal_error, res)
   else
      rest_utils.answer(rest_utils.consts.success.ok, res)
   end

   return
end

-- Add metadata
res.schema = ts_schema
res.query = tags
res.max_points = options.max_num_points

if not isEmptyString(compare_backward) and compare_backward ~= "1Y" and (res.step ~= nil) then
  local backward_sec = graph_common.getZoomDuration(compare_backward)
  local tstart_cmp = res.start - backward_sec
  local tend_cmp = tstart_cmp + res.step * (res.count - 1)

  -- Try to use the same aggregation as the original query
  local res_cmp = performQuery(tstart_cmp, tend_cmp, true, {target_aggregation=res.source_aggregation})
  local total_cmp_serie = nil

  if res_cmp and res_cmp.additional_series and res_cmp.additional_series.total and (res_cmp.step) and res_cmp.step >= res.step then
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

if extend_labels and graph_utils.extendLabels then
   graph_utils.extendLabels(res)
end

-- Add layout information
local layout = graph_utils.get_timeseries_layout(ts_schema)

for _, serie in pairs(res.series) do

  if not serie.type then
    if layout[serie.label] then
      serie.type = layout[serie.label]
    end
  end

end

if extended_times then
  if res.series and res.step then
    for k, serie in pairs(res.series) do
      serie.data = ts_common.serieWithTimestamp(serie.data, tstart, res.step)
    end
  end
  if res.additional_series and res.step then
    for k, serie in pairs(res.additional_series) do
      res.additional_series[k] = ts_common.serieWithTimestamp(serie, tstart, res.step)
    end
  end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
