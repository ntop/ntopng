--
-- (C) 2017-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local os_utils = require "os_utils"

local callback_utils = {}

-- ########################################################

-- Iterates available interfaces, excluding PCAP interfaces.
-- Each valid interface is select-ed and passed to the callback.
-- NOTE: direction must only be used by second.lua
function callback_utils.foreachInterface(ifnames, condition, callback, update_direction_stats)
   for _,_ifname in pairs(ifnames) do
      if(ntop.isShutdown()) then return true end

      -- NOTE: "eth" will be overwritten here for emulated directions
      interface.select(_ifname)

      if update_direction_stats then
	 interface.updateDirectionStats()
      end

      local ifstats = interface.getStats()

      if condition == nil or condition(ifstats.id) then
	 if((ifstats.type ~= "pcap dump") and (ifstats.type ~= "unknown")) then
	    if callback(_ifname, ifstats, false) == false then
	       return false
	    end
	 end
      end
   end

   return true
end

-- ########################################################

-- An iterator on the C batched API
--
--    batched_function: the function to call
--    field: a string to get the value from a slot
--    function_params : parameters to pass to the function
--
local function getBatchedIterator(batched_function, field, function_params)
   local debug_enabled = false
   local loaded_elems = nil
   local nextSlot = 0
   local iterator_finished = false
   local first_iteration = true
   function_params = function_params or {}

   return function()
      if (loaded_elems == nil) or table.empty(loaded_elems) then
         if loaded_elems ~= nil then
            -- that was the first iteration
            first_iteration = false
         end

         if ((nextSlot == 0) or (nextSlot == nil)) and not first_iteration then
            iterator_finished = true
         end

         if iterator_finished then
	    return nil
	 end

         -- we need to load new slots from C
         if(debug_enabled) then
            io.write("getBatchedIterator["..field.."](curSlot=".. nextSlot ..")\n")
         end

         -- Assumption: nextSlot is always the first parameter
         local slot = batched_function(nextSlot, table.unpack(function_params))

         if slot == nil then
            iterator_finished = true
            return nil
         end

         nextSlot = slot.nextSlot
         loaded_elems = slot[field]

         if(debug_enabled) then
            io.write("getBatchedIterator["..field.."] nextSlot=".. nextSlot ..")\n")
         end

      end

      for key, value in pairs(loaded_elems) do
         loaded_elems[key] = nil -- pop
         return key, value
      end
   end
end

-- A batched iterator over the active flows
-- @param flows_filter A table containing flow filters matching those specified in Paginator.cpp
function callback_utils.getFlowsIterator(flows_filter)
   return getBatchedIterator(interface.getBatchedFlowsInfo, "flows",  flows_filter)
end

-- A batched iterator over the local hosts with timeseries
function callback_utils.getLocalHostsTsIterator(...)
   return getBatchedIterator(interface.getBatchedLocalHostsTs, "hosts", { ... })
end

-- A batched iterator over the local hosts
function callback_utils.getLocalHostsIterator(...)
   return getBatchedIterator(interface.getBatchedLocalHostsInfo, "hosts", { ... })
end

-- A batched iterator over the remote hosts
function callback_utils.getRemoteHostsIterator(...)
   return getBatchedIterator(interface.getBatchedRemoteHostsInfo, "hosts", { ... })
end

-- A batched iterator over the hosts (both local and remote)
function callback_utils.getHostsIterator(...)
   return getBatchedIterator(interface.getBatchedHostsInfo, "hosts", { ... })
end

-- A batched iterator over the l2 devices
function callback_utils.getDevicesIterator(...)
   return getBatchedIterator(interface.getBatchedMacsInfo, "macs", { ... })
end

-- ########################################################

-- Iterates each active flow on the ifname interface.
-- Each flow is passed to the callback with some more information.
function callback_utils.foreachFlow(ifname, deadline, callback, ...)
   interface.select(ifname)

   local iterator = callback_utils.getFlowsIterator({...})

   for flow_key, flow in iterator do

      if(ntop.isShutdown()) then return true end

      if ((deadline ~= nil) and (os.time() >= deadline)) then
	 -- Out of time
	 return false
      end

      if callback(flow_key, flow) == false then
	 return false
      end
   end

   return true
end

-- ########################################################

-- Iterates each active host on the ifname interface for RRD creation.
-- Each host is passed to the callback with some more information.
function callback_utils.foreachLocalRRDHost(ifname, with_ts, with_one_way_traffic_hosts, callback)
   interface.select(ifname)

   local iterator

   if with_ts then
      iterator = callback_utils.getLocalHostsTsIterator(nil --[[ show_details --]], nil --[[ maxHits --]], nil --[[ anomalousOnly --]], with_one_way_traffic_hosts)
   else
      iterator = callback_utils.getLocalHostsIterator(false --[[ show_details --]], nil --[[ maxHits --]], nil --[[ anomalousOnly --]], with_one_way_traffic_hosts)
   end

   for hostname, host_ts in iterator do
      if(ntop.isShutdown()) then return true end
      if ntop.isDeadlineApproaching() then
	 -- Out of time
	 return false
      end

	 if callback(hostname, host_ts) == false then
	    return false
	 end
   end

   return true
end

-- ########################################################

-- Iterates each active host on the ifname interface.
-- Each host is passed to the callback with some more information.
function callback_utils.foreachHost(ifname, callback)
   interface.select(ifname)

   local iterator = callback_utils.getHostsIterator(false --[[ no details ]])

   for hostname, hoststats in iterator do
      if(ntop.isShutdown()) then return true end

      if ntop.isDeadlineApproaching() then
	 -- Out of time
	 return false
      end

      if callback(hostname, hoststats) == false then
	 return false
      end
   end

   return true
end

-- ########################################################

-- Iterates each active host on the ifname interface.
-- Each host is passed to the callback with some more information.
function callback_utils.foreachLocalHost(ifname, callback)
   interface.select(ifname)

   local iterator = callback_utils.getLocalHostsIterator(false --[[ no details ]])

   for hostname, hoststats in iterator do
      if(ntop.isShutdown()) then return true end

      if ntop.isDeadlineApproaching() then
	 -- Out of time
	 return false
      end

      if callback(hostname, hoststats) == false then
	 return false
      end
   end

   return true
end

-- Iterates each device on the ifname interface.
-- Each device is passed to the callback with some more information.
function callback_utils.foreachDevice(ifname, callback)
   interface.select(ifname)

   local devices_stats = callback_utils.getDevicesIterator()

   for devicename, devicestats in devices_stats do
      if(ntop.isShutdown()) then return true end
      devicename = hostinfo2hostkey(devicestats) -- make devicename the combination of mac address and vlan

      if ntop.isDeadlineApproaching() then
         -- Out of time
         return false
      end

      if callback(devicename, devicestats) == false then
	 return false
      end
   end

   return true
end

-- ########################################################

function callback_utils.uploadTSdata()
   local ts_utils = require("ts_utils_core")
   local drivers = ts_utils.listActiveDrivers()
   ts_utils.setup()

   for _, driver in ipairs(drivers) do
      driver:export()
   end
end
-- ########################################################

return callback_utils
