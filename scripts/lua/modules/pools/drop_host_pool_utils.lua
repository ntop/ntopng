--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local pools = require "pools"
local host_pools = require "host_pools"
local checks = require "checks"

-- Retrieve the info from the pool
local pool_info = ntop.getDropPoolInfo()

local is_ids_ips_log_enabled = checks.isSystemScriptEnabled("ids_ips_log")

local drop_host_pool_utils = {}

-- A couple of queues keeping events
drop_host_pool_utils.ids_ips_jail_add_key = "ntopng.cache.ids_ips_jail_add"
drop_host_pool_utils.ids_ips_jail_remove_key = "ntopng.cache.ids_ips_jail_remove"

drop_host_pool_utils.max_ids_ips_log_queue_len = 1024

-- ############################################

local DROP_HOST_POOL_HOST_IN_JAIL = "ntopng.cache.jail.time.%s" -- Sync with ntop_defines.h DROP_HOST_POOL_PRE_JAIL_POOL
local DROP_HOST_POOL_PRE_JAIL_POOL = "ntopng.prefs.jail.pre_jail_pool.%s" -- Sync with ntop_defines.h DROP_HOST_POOL_PRE_JAIL_POOL

-- ############################################

function drop_host_pool_utils.check_pre_banned_hosts_to_add()
   local queue_name = "ntopng.cache.tmp_add_host_list"
   local changed = false
   local host_pool, jailed_pool

   local num_pending = ntop.llenCache(queue_name)

   while num_pending > 0 do
      local elem = ntop.lpopCache(queue_name)

      if not host_pool then
	 -- Lazily initialize the jailed pool
	 host_pool = host_pools:create()
	 jailed_pool = host_pool:get_pool_by_name(host_pools.DROP_HOST_POOL_NAME)

	 if not jailed_pool then
	    -- Jailed pool cannot be found, unable to continue
	    return
	 end
      end

      -- Add elem to the jailed host pool
      local res, err = host_pool:bind_member(elem, jailed_pool.pool_id)

      if is_ids_ips_log_enabled then
	 ntop.rpushCache(drop_host_pool_utils.ids_ips_jail_add_key, elem, drop_host_pool_utils.max_ids_ips_log_queue_len)
      end

      if not changed then
	 changed = true
      end

      num_pending = num_pending - 1
   end

   -- Read rules from configured pools and policies
   -- and push rules to the nProbe listeners
   if(changed) then
      if ntop.isPro() then
	 package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
	 local policy_utils = require "policy_utils"

	 local rsp = policy_utils.get_ips_rules()
	 if(rsp ~= nil) then
	    ntop.broadcastIPSMessage(rsp)
	 end
      end
   end
end

-- ############################################

-- This function checks if the are banned hosts that need to be unbanned

function drop_host_pool_utils.check_periodic_hosts_list()
   local changed = false

   -- Get the jailed pool
   local host_pool = host_pools:create()
   local jailed_pool = host_pool:get_pool_by_name(host_pools.DROP_HOST_POOL_NAME)

   if not jailed_pool then
      return
   end

   for _, member in pairs(jailed_pool.members) do
      -- Check if the DROP_HOST_POOL_HOST_IN_JAIL no longer exists
      local still_jailed_key = string.format(DROP_HOST_POOL_HOST_IN_JAIL, member)
      local still_jailed = ntop.getCache(still_jailed_key)

      -- If the key is nil, it means the TTL has expired and it is time to remove the host from the jail
      if isEmptyString(still_jailed) then
	 -- Check if there's a key indicating the host pool before the jail
	 local pre_jail_pool_key = string.format(DROP_HOST_POOL_PRE_JAIL_POOL, member)
	 local pre_jail_pool = ntop.getCache(pre_jail_pool_key)

	 local ret = false
	 if not isEmptyString(pre_jail_pool) then
	    -- Bind to the old pool. If bind is successful, i.e., pool still exists,
	    -- then ret becomes true.
	    ret = host_pool:bind_member(member, pre_jail_pool)
	 end

	 if not ret then
	    -- Bind to the default pool
	    ret = host_pool:bind_member(member, pools.DEFAULT_POOL_ID)
	 end

	 if ret then
	    if is_ids_ips_log_enabled then
	       ntop.rpushCache(drop_host_pool_utils.ids_ips_jail_remove_key, value, drop_host_pool_utils.max_ids_ips_log_queue_len)
	    end

	    changed = true
	 end
      end
   end

   -- Read rules from configured pools and policies
   -- and push rules to the nProbe listeners
   if(changed) then
      if ntop.isPro() then
	 package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
	 local policy_utils = require "policy_utils"

	 local rsp = policy_utils.get_ips_rules()
	 if(rsp ~= nil) then
	    ntop.broadcastIPSMessage(rsp)
	 end
      end
   end
end

-- ############################################

return drop_host_pool_utils
