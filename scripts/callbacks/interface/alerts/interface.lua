--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"

alerts_api = require("alerts_api")

local do_trace      = false
local config_alerts = nil
local ifname        = nil

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if(do_trace) then print("alert.lua:setup("..str_granularity..") called\n") end
   ifname = interface.setActiveInterfaceId(tonumber(interface.getId()))
   config_alerts = getInterfaceConfiguredAlertThresholds(ifname, str_granularity)

   -- Load the threashold checking functions
   package.path = dirs.installdir .. "/scripts/callbacks/interface/alerts/interface/?.lua;" .. package.path
   require("check")
end

-- #################################################################

-- The function below is called once per interface
local function checkInterfaceAlertsThreshold(interface_key, interface_info, granularity, num_granularity, rules)
   if(do_trace) then print("checkInterfaceAlertsThreshold()\n") end

   local ifid = interface.getId()

   for function_name,params in pairs(rules) do
      -- IMPORTANT: do not use "local" with the variables below
      --            as they need to be accessible by the evaluated function
      threshold_value    = params["edge"]
      alert_key_name     = params["key"]
      threshold_operator = params["operator"]
      metric_name        = params["metric"]
      threshold_gran     = granularity
      threshold_num_gran = num_granularity
      i_info             = interface_info

      if(do_trace) then print("[Alert @ "..granularity.."] ".. interface_key .." ["..function_name.."]\n")  end

      if(true) then
	 -- This is where magic happens: load() evaluates the string
	 local what = 'return('..function_name..'(metric_name, i_info, threshold_gran, threshold_num_gran))'
	 -- print(what)
	 local func, err = load(what)

	 if func then
	    local ok, value = pcall(func)

	    if ok then
	       local alarmed = false
	       local interface_alert = alerts_api:newAlert({ entity = "host", type = "threshold_cross", severity = "error" })

	       if(do_trace) then print("Execution OK. value: "..tostring(value)..", operator: "..threshold_operator..", threshold: "..threshold_value.."]\n") end

	       threshold_value = tonumber(threshold_value)

	       if(threshold_operator == "lt") then
		  if(value < threshold_value) then alarmed = true end
	       else
		  if(value > threshold_value) then alarmed = true end
	       end

	       if(alarmed) then
                  if(do_trace) then print("Trigger alert [value: "..tostring(value).."]\n")  end

                  alerts_api.new_trigger(
                      alerts_api.interfaceAlertEntity(ifid),
                      alerts_api.thresholdCrossType(granularity, function_name, value, threshold_operator, threshold_value)
                  )
	       else
		  if(do_trace) then print("DON'T trigger alert [value: "..tostring(value).."]\n") end
 
                  alerts_api.new_trigger(
                      alerts_api.interfaceAlertEntity(ifid),
                      alerts_api.thresholdCrossType(granularity, function_name, value, threshold_operator, threshold_value)
                  )
	       end
	    else
	       if(do_trace) then print("Execution error:  "..tostring(rc).."\n") end
	    end
	 else
	    print("Compilation error:", err)
	 end
      end

      if(do_trace) then print("=============\n") end
   end
end

-- #################################################################

-- The function below is called once per host
function checkInterfaceAlerts(granularity)
   local info = interface.getStats()
   local interface_key   = "iface_"..interface.getId()
   local interface_alert = config_alerts[interface_key]
   local num_granularity = granularity2id(granularity)
   
   if(do_trace) then print("checkInterfaceAlerts()\n") end

   -- specific host alerts
   if((interface_alert ~= nil) and (table.len(interface_alert) > 0)) then
      checkInterfaceAlertsThreshold(interface_key, info, granularity, num_granularity, interface_alert)
   end

   -- generic host alerts
   interface_alert = config_alerts["interfaces"]
   if((interface_alert ~= nil) and (table.len(interface_alert) > 0)) then
      checkInterfaceAlertsThreshold(interface_key, info, granularity, num_granularity, interface_alert)
   end
end
