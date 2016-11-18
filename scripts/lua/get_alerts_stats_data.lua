--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require('dkjson')

local min_align = function(secs) return secs - (secs % 60) end

local stats_type = _GET["stats_type"]
local period_mins  = 60  -- TODO: make it configurable
local now = os.time()
local period_begin = min_align(now - period_mins * 60)

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)


local res = {}
local aggr = {}

local selection
local aggregation
local labeller
if stats_type == "severity_pie" or stats_type == "type_pie"
  or stats_type == "count_sparkline" or stats_type == "top_hosts"
  or stats_type == "top_origins" or stats_type == "top_targets" then
   if stats_type == "severity_pie" then
      selection   = "alert_severity as label, count(*) as value"
      aggregation = "where alert_tstamp >= ".. period_begin .." group by label"
      labeller = alertSeverityLabel
   elseif stats_type == "type_pie" then
      selection   = "alert_type as label, count(*) as value"
      aggregation = "where alert_tstamp >= ".. period_begin .." group by label"
      labeller = alertTypeLabel
   elseif stats_type == "count_sparkline" then
      selection = "(alert_tstamp - alert_tstamp % 60) as label, count(*) as value"
      aggregation = "where alert_tstamp >= ".. period_begin .." group by label"
      labeller = nil
   elseif stats_type == "top_hosts" then
      selection   = "alert_entity_val as label, count(*) as value"
      aggregation = "where alert_entity = "..alertEntity("host")
      aggregation = aggregation.." and alert_tstamp >= ".. period_begin
      aggregation = aggregation.." group by label order by value desc limit 5"
      labeller = nil
   elseif stats_type == "top_origins" then
      selection   = "alert_origin as label, count(*) as value"
      aggregation = "where alert_tstamp >= ".. period_begin
      aggregation = aggregation.." and alert_origin is not null "
      aggregation = aggregation.." group by label order by value desc limit 5"
      labeller = nil
   elseif stats_type == "top_targets" then
      selection   = "alert_target as label, count(*) as value"
      aggregation = "where alert_tstamp >= ".. period_begin
      aggregation = aggregation.." and alert_target is not null "
      aggregation = aggregation.." group by label order by value desc limit 5"
      labeller = nil
   end
   for _, engaged in pairs({true, false}) do
      local r = interface.selectAlertsRaw(engaged, selection, aggregation)
      if r == nil then r = {} end
      -- must aggregate again to sum counters between engaged and closed alerts
      for k, v in ipairs(r) do

	 if v["label"] ~= nil and labeller ~= nil then
	    v["label"] = labeller(v["label"], true)
	 end

	 if aggr[v["label"]] ~= nil then
	    aggr[v["label"]] = aggr[v["label"]] + v["value"]
	 else
	    aggr[v["label"]] = v["value"]
	 end

      end
   end

elseif stats_type == "duration_pie" then

   local binner = function(value)
      value = tonumber(value)
      if value == nil then return nil end
      local bin
      if value < 60 then bin = "[0,1)"
      elseif value < 60 * 5 then bin = "[1,5)"
      elseif value < 60 * 10 then bin = "[5,10)"
      else bin = "10+" end
      -- local log_base = 2
      -- local bin = math.floor(math.log(value) / math.log(log_base))
      -- bin = tostring(log_base^bin).." s <= d < "..tostring(log_base^(bin+1)).." s"
      return bin.." min"
   end

   -- engaged
   -- the duration is the current instant minus the alert timestamp
   local engaged_selection   = "(strftime('%s','now') - alert_tstamp) as label, count(*) as value"
   local engaged_aggregation = "where alert_tstamp >= ".. period_begin .. " group by label"
   -- not engaged
   -- the duration is the difference between the end and the start time
   local closed_selection   = "(alert_tstamp_end - alert_tstamp) as label, count(*) as value"
   -- we don't take into account 'instant' alerts
   local closed_aggregation = "where alert_tstamp >= ".. period_begin .. " and alert_tstamp_end is not null group by label"

   local r_engaged = interface.selectAlertsRaw(true, engaged_selection, engaged_aggregation)
   if r_engaged == nil then r_engaged = {} end

   local r_closed = interface.selectAlertsRaw(false, closed_selection, closed_aggregation)
   if r_closed == nil then r_closed = {} end

   -- let's put things together
   for _, r in pairs({r_engaged, r_closed}) do
      for k, v in ipairs(r) do
	 if v["label"] ~= nil then
	    v["label"] = binner(v["label"])
	 end
	 if aggr[v["label"]] ~= nil then
	    aggr[v["label"]] = aggr[v["label"]] + v["value"]
	 else
	    aggr[v["label"]] = v["value"]
	 end
      end
   end

elseif stats_type == "longest_engaged" then
   local closed_selection = "alert_entity as ae, alert_entity_val as av, sum(alert_tstamp_end - alert_tstamp) as total_time"
   local closed_aggregation = "where alert_tstamp >= ".. period_begin
   closed_aggregation = closed_aggregation.." and alert_tstamp_end is not null "
   closed_aggregation = closed_aggregation.." group by alert_entity, alert_entity_val"

   local engaged_selection = "alert_entity as ae, alert_entity_val as av, sum(strftime('%s','now') - alert_tstamp) as total_time"
   local engaged_aggregation = "where alert_tstamp >= ".. period_begin
   engaged_aggregation = engaged_aggregation.." group by alert_entity, alert_entity_val"

   local r_closed = interface.selectAlertsRaw(false, closed_selection, closed_aggregation);
   local r_engaged = interface.selectAlertsRaw(true, engaged_selection, engaged_aggregation);

   for _, r in pairs({r_engaged, r_closed}) do
      for k, v in ipairs(r) do
	 local label = alertEntityLabel(tonumber(v["ae"])) .. "_" .. v["av"]
	 if aggr[label] ~= nil then
	    aggr[label] = aggr[label] + v["total_time"]
	 else
	    aggr[label] = v["total_time"]
	 end
      end
   end

elseif stats_type == "counts_pie" then

   local num_engaged = interface.getNumAlerts(true, now - period_mins * 60)
   local num_closed = interface.getNumAlerts(false, now - period_mins * 60)
   if num_engaged > 0 then aggr["Engaged"] = num_engaged end
   if num_closed > 0 then aggr["Closed"] = num_closed end

elseif stats_type == "counts_plain" then
   for _, range in pairs({{"count-last-minute", 60}, {"count-last-hour", 3600},
	 {"count-last-day", 86400}, {"count-last-period", period_mins * 60}}) do
      local num_engaged = interface.getNumAlerts(true, now - range[2])
      local num_closed = interface.getNumAlerts(false, now - range[2])
      aggr[range[1]] = num_engaged + num_closed
   end
end

-- post-processing before last aggregation
if stats_type == "count_sparkline" then
   local time_now = min_align(now)
   local time_range_min = min_align(now - period_mins * 60)
   -- add padding to the table
   for minute=time_range_min,time_now,60 do
      minute = tostring(minute)
      if aggr[minute] == nil then
	 aggr[minute] = 0
      end
   end

   --prepare the final result
   for k, v in pairsByKeys(aggr, rev) do
      res[#res + 1] = tonumber(v)
   end
elseif stats_type == "counts_plain" then
   res = aggr
elseif stats_type == "top_hosts" or stats_type == "top_origins" or stats_type == "top_targets" then
   for k, v in pairs(aggr) do aggr[k] = tonumber(v) end
   for k, v in pairsByValues(aggr, rev) do
      res[#res + 1] = {host=k, value=v}
   end
elseif stats_type == "longest_engaged" then
   for k, v in pairs(aggr) do aggr[k] = tonumber(v) end
   local count = 1
   for k, v in pairsByValues(aggr, rev) do
      res[#res + 1] = {entity=k, total_time=v}
      count = count + 1
      if count > 5 then break end
   end
else
   for k, v in pairs(aggr) do
      res[#res + 1] = {label=k, value=tonumber(v)}
   end
end

print(json.encode(res, nil))
