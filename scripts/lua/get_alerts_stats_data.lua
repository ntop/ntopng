--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require('dkjson')

local stats_type = _GET["stats_type"]

sendHTTPHeader('text/html; charset=iso-8859-1')

interface.select(ifname)


local res = {}
local aggr = {}

local selection
local aggregation
local labeller
if stats_type == "severity_pie" or stats_type == "type_pie" then
   if stats_type == "severity_pie" then
      selection   = "alert_severity as label, count(*) as value"
      aggregation = "group by label"
      labeller = alertSeverityLabel
   elseif stats_type == "type_pie" then
      selection   = "alert_type as label, count(*) as value"
      aggregation = "group by label"
      labeller = alertTypeLabel
   end
   for _, engaged in pairs({true, false}) do
      local r = interface.selectAlertsRaw(engaged, selection, aggregation)
      if r == nil then r = {} end
      -- must aggregate again to sum counters between engaged and closed alerts
      for k, v in ipairs(r) do

	 if v["label"] ~= nil then
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
   selection   = "(strftime('%s','now') - alert_tstamp) as label, count(*) as value"
   aggregation = "group by label"
   local r_engaged = interface.selectAlertsRaw(true, selection, aggregation)
   if r_engaged == nil then r_engaged = {} end

   -- not engaged
   -- the duration is the difference between the end and the start time
   selection   = "(alert_tstamp_end - alert_tstamp) as label, count(*) as value"
   -- we don't take into account 'instant' alerts
   aggregation = "where alert_tstamp_end is not null group by label"
   local r_closed = interface.selectAlertsRaw(false, selection, aggregation)
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
elseif stats_type == "counts_pie" then
   aggr["Engaged"] = interface.getNumAlerts(true)
   aggr["Closed"] = interface.getNumAlerts(false)
end

for k, v in pairs(aggr) do
   res[#res + 1] = {label=k, value=tonumber(v)}
end

print(json.encode(res, nil))
