--
-- (C) 2013-22 - ntop.org
--

--
-- Module used to build threshold-based timeseries checks
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local ts_utils = require "ts_utils"
local callback_utils = require "callback_utils"
local json = require "dkjson"

local host_threshold_check_rules = {}

-- ########################################################

local function sum_series(data)
   local total = 0
   if(data ~= nil) then
      local series = data.series

      for i=1,#series do
	 -- 1=bytes_sent, 2=bytes_rcvd
	 -- tprint(series[i].label)

	 for k,v in pairs(series[i].data) do
	    -- sum rx and tx
	    total = total + series[i].data[k] * data.step
	 end
      end
   end

   return(math.floor(total))
end

-- ########################################################

local function host_l7_ts(ifid, hostkey, l7_proto, start_time, end_time)
   local schema = "host:ndpi"
   local tags = {
      ifid = ifid,
      host = hostkey,
      protocol = l7_proto
   }

   local data = ts_utils.query(schema, tags, start_time, end_time)
   
   return(sum_series(data))
end

-- ########################################################

local function host_ts(ifid, schema, hostkey, start_time, end_time)
   local tags = { ifid = ifid, host = hostkey }
   local data = ts_utils.query(schema, tags, start_time, end_time)
   return(sum_series(data))
end

-- ########################################################

local function host_bytes(ifid, hostkey, start_time, end_time)
   return(host_ts(ifid, "host:traffic", hostkey, start_time, end_time))
end

-- ########################################################

local function host_score(ifid, hostkey, start_time, end_time)
   return(host_ts(ifid, "host:score", hostkey, start_time, end_time))
end

-- ########################################################

local function eval_metric(metric, ifid, hostname, start_time, end_time)
   local tot = 0
  
   if(metric == "bytes") then
      tot = host_bytes(ifid, hostname, start_time, end_time)
   elseif(metric == "score") then
      tot = host_bytes(ifid, hostname, start_time, end_time)
   else
      tot = host_l7_ts(ifid, hostname, metric, start_time, end_time)
   end

   -- tprint(ifid .."/".. hostname  .."/".. metric  .."/".. start_time .."/".. end_time .."/".. tot)
   
   return(tot)
end

-- ########################################################

-- function called when threshold is crossed
local function trigger_alert_error(if_name, ifid, hostname, value, threshold, rule, start_time, end_time)
   print(hostname.." = ".. value .. " [".. rule.metric .."] ALERT\n") -- FIXME
end

-- ########################################################

-- function called when threshold is not crossed (OK)
local function trigger_alert_ok(if_name, ifid, hostname, value, threshold, rule, start_time, end_time)
   print(hostname.." = ".. value .. " [".. rule.metric .."] OK\n") -- FIXME
end

-- ########################################################

local function interpret_rule(if_name, ifid, frequency, r)
   local duration
   local threshold

   if(frequency ~= r.frequency) then
      return(1)
   end

   if(r.threshold == nil) then
      return(-1)
   else
      threshold = tonumber(r.threshold)
   end

   if(r.frequency == "daily") then
      duration = 86400
   else if(r.frequency == "hourly") then
	 duration = 3600
	else
	   return(-2)
	end
   end

   local end_time   = os.time()
   local start_time = end_time - duration

   if(r.target == nil) then
      return(-3)
   elseif(r.target == "*") then
      -- scan all active local hosts
      callback_utils.foreachLocalTimeseriesHost(if_name,
						true --[[ timeseries ]],
						false --[[ consider only hosts with RX+TX traffic ]],
						function (hostname, host_ts)
						   local tot = eval_metric(r.metric, ifid, hostname, start_time, end_time)

						   if(tot > threshold) then
						      trigger_alert_error(if_name, ifid, hostname, tot, threshold, r, start_time, end_time)
						   else
						      trigger_alert_ok(if_name, ifid, hostname, tot, threshold, r, start_time, end_time)

						   end
						  end
      )
   else
      local hostname = r.target
      local tot = eval_metric(r.metric, ifid, hostname, start_time, end_time)

      if(tot > threshold) then
         trigger_alert_error(if_name, ifid, hostname, tot, threshold, r, start_time, end_time)
      else
         trigger_alert_ok(if_name, ifid, hostname, tot, threshold, r, start_time, end_time)
      end
   end

   return(0)
end

-- ########################################################

function host_threshold_check_rules.check_threshold_rules(if_name, ifid, frequency)
   local num = 1
   local key = "ntopng.prefs.ifid_"..ifid..".host_threshold_rules"
   local rules = ntop.getCache(key)

   if((rules == nil) or (rules == "")) then
      return
   else
      rules = json.decode(rules)
   end

   for _,rule in ipairs(rules) do
      local rc = interpret_rule(if_name, ifid, frequency, rule)

      if(rc < 0) then
	 print("Unable to interpret rule "..num)
      end

      num = num + 1
   end
end

-- ########################################################

return host_threshold_check_rules