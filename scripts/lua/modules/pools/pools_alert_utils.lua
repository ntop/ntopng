--
-- (C) 2020 - ntop.org
--
-- This file contains the alert constats

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local alert_consts = require "alert_consts"
local base_pools = require "base_pools"

-- ################################################################################

local pools_alert_utils = {}
local alert_entity_pool_instances = {}

-- ################################################################################

-- @brief Returns the pools of a given `entity_id`
function pools_alert_utils.get_entity_pools_by_id(entity_id)
   local alert_entity = alert_consts.alertEntityById(entity_id)

   if not alert_entity then
      return nil
   end

   if not alert_entity_pool_instances[alert_entity.entity_id] then
      if not alert_entity.pools then
         return nil
      end
      local pools = require(alert_entity.pools)
      alert_entity_pool_instances[alert_entity.entity_id] = pools:create()
   end

   return alert_entity_pool_instances[alert_entity.entity_id]
end

-- ################################################################################

-- @brief Returns the pool id of a given `entity_info`
function pools_alert_utils.get_entity_pool_id(entity_info)
   local alert_entity = entity_info.alert_entity
   local pool_member = entity_info.alert_entity_val
   local res = base_pools.DEFAULT_POOL_ID

   -- There's no pool member or the alert entity is invalid
   if not pool_member or not alert_entity or not alert_entity.entity_id or not alert_entity.pools then
      -- tprint(string.format("skipping %s [%s]", pool_member, alert_entity.label or ''))
      return base_pools.DEFAULT_POOL_ID
   end

   if not alert_entity_pool_instances[alert_entity.entity_id] then
      local pools = require(alert_entity.pools)
      alert_entity_pool_instances[alert_entity.entity_id] = pools:create()
   end

   if alert_entity_pool_instances[alert_entity.entity_id] then
      res = alert_entity_pool_instances[alert_entity.entity_id]:get_pool_id(pool_member)
      -- tprint(string.format("found pool %u for %s [%s]", res, pool_member, alert_entity.label))
      return res
   end

   -- tprint(string.format("Pool NOT found for %s [%s]", pool_member, alert_entity.label))
   return base_pools.DEFAULT_POOL_ID
end

-- ################################################################################

return pools_alert_utils
