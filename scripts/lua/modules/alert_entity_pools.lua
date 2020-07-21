--
-- (C) 2020 - ntop.org
--
-- This file contains the alert constats

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local alert_consts = require "alert_consts"
local base_pools = require "base_pools"

-- ################################################################################

local alert_entity_pools = {}
local alert_entity_pool_instances = {}

-- ################################################################################

function alert_entity_pools.get_entity_pool_id(entity_info)
   local alert_entity = entity_info.alert_entity
   local pool_member = entity_info.alert_entity_val
   local res = base_pools.DEFAULT_POOL_ID

   -- There's no pool member or the alert entity is invalid
   if not pool_member or not alert_entity or not alert_entity.entity_id or not alert_entity.pools then
      return base_pools.DEFAULT_POOL_ID
   end

   if not alert_entity_pool_instances[alert_entity.entity_id] then
      alert_entity_pool_instances[alert_entity.entity_id] = require(alert_entity.pools):create()
   end

   if alert_entity_pool_instances[alert_entity.entity_id] then
      res = alert_entity_pool_instances[alert_entity.entity_id]:get_pool_id(pool_member)
--      tprint(string.format("found %u for %s", res, pool_member))
   end

   return base_pools.DEFAULT_POOL_ID
end

-- ################################################################################

return alert_entity_pools
