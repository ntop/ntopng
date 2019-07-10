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
   config_alerts = getNetworksConfiguredAlertThresholds(ifname, str_granularity)

   -- Load the threshold checking functions
   package.path = dirs.installdir .. "/scripts/callbacks/interface/alerts/network/?.lua;" .. package.path
   checks = require("check")
end

-- #################################################################

-- The function below is called once per network
local function checkNetworkAlertsThreshold(network_key, network_info, granularity, num_granularity, rules)
   if do_trace then print("checkNetworkAlertsThreshold()\n") end

   for function_name, params in pairs(rules) do
      -- IMPORTANT: do not use "local" with the variables below
      --            as they need to be accessible by the evaluated function
      threshold_value    = params["edge"]
      alert_key_name     = params["key"]
      threshold_operator = params["operator"]
      metric_name        = params["metric"]
      threshold_gran     = granularity
      threshold_num_gran = num_granularity
      n_info             = network_info

      print("[Alert @ "..granularity.."] ".. network_key .." ["..function_name.."]\n")

      if true then
         -- This is where magic happens: load() evaluates the string
         local what = 'return checks.'..function_name..'(metric_name, n_info, threshold_gran, threshold_num_gran)'
         local func, err = load(what, 't')

         if func then
            local ok, value = pcall(func)

            if ok then
               local alarmed = false
               local network_alert = alerts_api:newAlert({entity = "network", type = "threshold_cross", severity = "error"})

               if do_trace then print("Execution OK. value: "..tostring(value)..", operator: "..threshold_operator..", threshold: "..threshold_value.."]\n") end

               threshold_value = tonumber(threshold_value)

               if threshold_operator == "lt" then
                  if value < threshold_value then alarmed = true end
               else
                  if value > threshold_value then alarmed = true end
               end

               if alarmed then
                  if interface.storeTriggeredAlert(alert_key_name, num_granularity) then
                     -- IMPORTANT: uncommenting the line below break all
                     -- network_alert:trigger(network_key, "Network "..network_key.." crossed threshold "..metric_name)
                     print("Trigger alert [value: "..tostring(value).."]\n")
                  end
               else
                  if interface.releaseTriggeredAlert(alert_key_name, num_granularity) then
                     print("DON'T trigger alert [value: "..tostring(value).."]\n")
                     -- network_alert:release(network_key)
                  end
               end
            else
               if do_trace then print("Execution error:  "..tostring(rc).."\n") end
            end
         else
            print("Compilation error:", err)
         end
      end

      print("=============\n")
   end
end

-- #################################################################

-- The function below is called once per local network
function checkNetworkAlerts(granularity)
   local info = network.getNetworkStats()
   local network_key = info and info.network_key

   if not network_key then
      return
   end

   local network_alert = config_alerts[network_key]
   local num_granularity = granularity2id(granularity)

   -- specific network alerts
   if network_alert and table.len(network_alert) > 0 then
      checkNetworkAlertsThreshold(network_key, info, granularity, num_granularity, network_alert)
   end

   -- generic network alerts
   network_alert = config_alerts["local_networks"]
   if network_alert and table.len(network_alert) > 0 then
      checkNetworkAlertsThreshold(network_key, info, granularity, num_granularity, network_alert)
   end
end
