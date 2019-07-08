--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

alerts_api = require("alerts_api")

local do_trace      = true
local config_alerts = nil
local ifname        = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   print("alert.lua:setup("..str_granularity..") called\n")
   ifname = interface.setActiveInterfaceId(tonumber(interface.getId()))
   config_alerts = getHostsConfiguredAlertThresholds(ifname, str_granularity)

   -- Load the threshold checking functions
   package.path = dirs.installdir .. "/scripts/callbacks/interface/alerts/host/?.lua;" .. package.path
   checks = require("check")
end

-- #################################################################

-- The function below is called once per host
local function checkHostAlertsThreshold(host_key, host_info, granularity, num_granularity, rules)
   if(do_trace) then print("checkHostAlertsThreshold()\n") end

   for function_name,params in pairs(rules) do
      -- IMPORTANT: do not use "local" with the variables below
      --            as they need to be accessible by the evaluated function
      threshold_value    = params["edge"]
      alert_key_name     = params["key"]
      threshold_operator = params["operator"]
      metric_name        = params["metric"]
      threshold_gran     = granularity
      threshold_num_gran = num_granularity
      h_info             = host_info

      print("[Alert @ "..granularity.."] ".. host_key .." ["..function_name.."]\n")

      if(true) then
	 -- This is where magic happens: load() evaluates the string
	 local what = 'return checks.'..function_name..'(metric_name, h_info, threshold_gran, threshold_num_gran)'
	 -- tprint(what)
	 local func, err = load(what, 't')

	 if func then
	    local ok, value = pcall(func)

	    if ok then
	       local alarmed = false
	       local host_alert = alerts_api:newAlert({ entity = "host", type = "threshold_cross", severity = "error" })

	       if(do_trace) then print("Execution OK. value: "..tostring(value)..", operator: "..threshold_operator..", threshold: "..threshold_value.."]\n") end

	       threshold_value = tonumber(threshold_value)

	       if(threshold_operator == "lt") then
		  if(value < threshold_value) then alarmed = true end
	       else
		  if(value > threshold_value) then alarmed = true end
	       end

	       if(alarmed) then
		  if(host.storeTriggeredAlert(alert_key_name, num_granularity)) then
		     -- IMPORTANT: uncommenting the line below break all
		     -- host_alert:trigger(host_key, "Host "..host_key.." crossed threshold "..metric_name)
		     print("Trigger alert [value: "..tostring(value).."]\n")
		  end
	       else
		  if(host.releaseTriggeredAlert(alert_key_name, num_granularity)) then
		     print("DON'T trigger alert [value: "..tostring(value).."]\n")
		     -- host_alert:release(host_key)
		  end
	       end
	    else
	       if(do_trace) then print("Execution error:  "..tostring(rc).."\n") end
	    end
	 else
	    print("Compilation error:", err)
	 end
      end

      print("=============\n")
   end
end

-- #################################################################

-- The function below is called once per host
function checkHostAlerts(granularity)
   local info       = host.getFullInfo()
   local host_key   = info.ip.."@"..info.vlan
   local host_alert = config_alerts[host_key]
   local num_granularity = granularity2id(granularity)
   
   if(do_trace) then print("checkHostAlerts()\n") end

   -- specific host alerts
   if((host_alert ~= nil) and (table.len(host_alert) > 0)) then
      checkHostAlertsThreshold(host_key, info, granularity, num_granularity, host_alert)
   end

   -- generic host alerts
   host_alert = config_alerts["local_hosts"]
   if((host_alert ~= nil) and (table.len(host_alert) > 0)) then
      checkHostAlertsThreshold(host_key, info, granularity, num_granularity, host_alert)
   end
end
