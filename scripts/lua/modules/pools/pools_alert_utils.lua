--
-- (C) 2020 - ntop.org
--
-- This file contains the alert constats

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local pools = require "pools"

-- ################################################################################

local pools_alert_utils = {}
local alert_entity_pool_instances = {}
local alert_entity_all_pools = {}

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
   local res = pools.DEFAULT_POOL_ID

   -- There's no pool member or the alert entity is invalid
   if not pool_member or not alert_entity or not alert_entity.entity_id or not alert_entity.pools then
      -- tprint(string.format("skipping %s [%s]", pool_member, alert_entity.label or ''))
      return pools.DEFAULT_POOL_ID
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
   return pools.DEFAULT_POOL_ID
end

-- ################################################################################

-- @brief Returns an array of recipient ids responsible for a given an `entity_id` and a `pool_id`
-- @param entity_id One of alert_consts.alert_entities
-- @param pool_id The pool id of an existing entity pool
-- @param alert_severity An integer alert severity id as found in `alert_severities`
-- @param current_script The user script which has triggered this notification - can be nil if the script is unknown or not available
-- @return An array of recipient ids
function pools_alert_utils.get_entity_recipients_by_pool_id(entity_id, pool_id, alert_severity, current_script)
   local res = {}
   local entity = alert_consts.alertEntityById(entity_id)
   -- Obtain the pools instance for the given entity
   local pools_instance = pools_alert_utils.get_entity_pools_by_id(entity_id)

   if not pool_id then
      pool_id = pools.DEFAULT_POOL_ID
   end

   if pools_instance then
      -- tprint("found pool instance for "..entity.label)
      -- See if the pools for the current instance are in cache
      if not alert_entity_all_pools[entity_id] then
	 -- List of pools not yet cached, let's create it
	 alert_entity_all_pools[entity_id] = {}
	 local all_pools = pools_instance:get_all_pools()

	 -- It's handy to have the cache as a lua table with pool ids as keys and pool details as values
	 for _, pool in pairs(all_pools) do
	    alert_entity_all_pools[entity_id][pool.pool_id] = pool
	 end
      end

      -- Access the cache
      local entity_pool = alert_entity_all_pools[entity_id][pool_id]

      if entity_pool and entity_pool["recipients"] then
	 for _, recipient in pairs(entity_pool["recipients"]) do
	    local recipient_ok = false

	    if current_script and current_script.category and current_script.category.id and 
               recipient["recipient_check_categories"] ~= nil then
	       -- Make sure the user script category belongs to the recipient user script categories
	       for _, check_category in pairs(recipient["recipient_check_categories"]) do
		  if check_category == current_script.category.id then
		     recipient_ok = true
		  end
	       end
	    else
	       -- if there's no user script, check on the category id is not enforced
	       recipient_ok = true
	    end

	    if recipient_ok then
	       if alert_severity and recipient["recipient_minimum_severity"] ~= nil and 
                  alert_severity < recipient["recipient_minimum_severity"] then
		  -- If the current alert severity is less than the minimum requested severity
		  -- exclude the recipient
		  recipient_ok = false
	       end
	    end

	    if recipient_ok then
	       -- Prepare the result with all the recipients
	       res[#res + 1] = recipient.recipient_id
	       -- tprint(string.format("Adding recipient [%s][%s][%i]", recipient.recipient_name, entity.label, pool_id))
	    end
	 end
      end
   end

   return res
end

-- ################################################################################

return pools_alert_utils
