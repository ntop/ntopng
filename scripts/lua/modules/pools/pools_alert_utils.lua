--
-- (C) 2020 - ntop.org
--
-- This file contains the alert constats

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local alert_entities = require "alert_entities"
local pools = require "pools"

local host_pools_instance = nil

-- ################################################################################

local pools_alert_utils = {}

-- ################################################################################

-- @brief Returns the pool id of a given `entity_info`
function pools_alert_utils.get_host_pool_id(entity_info)
   local alert_entity = entity_info.alert_entity
   local pool_member = entity_info.entity_val

   -- There's no pool member or the alert entity is invalid
   if not pool_member or not alert_entity or not alert_entity.entity_id then
      -- tprint(string.format("skipping %s [%s]", pool_member, alert_entity.label or ''))
      return nil
   end

   -- Active Monitoring alert to Host
   if alert_entity == alert_entities.am_host then
      local am_host_info = split(pool_member, "@")
      if #am_host_info == 2 then
         pool_member = am_host_info[2]
      end
   -- SNMP alert to Host
   elseif alert_entity == alert_entities.snmp_device then
      local snmp_device_info = split(pool_member, "_")
      if #snmp_device_info >= 1 then
         pool_member = snmp_device_info[1]
      end
   else
      -- Host pool not supported (note: flow and host alerts are set in C)
      return nil
   end

   if not host_pools_instance then
      local host_pools = require "host_pools"
      host_pools_instance = host_pools:create()
   end

   if not host_pools_instance then
      -- tprint(string.format("Pool NOT found for %s [%s]", pool_member, alert_entity.label))
      return nil
   end

   local res = host_pools_instance:get_pool_id(pool_member)

   -- tprint(string.format("Found pool %u for %s", res, pool_member))

   return res
end

-- ################################################################################

return pools_alert_utils
