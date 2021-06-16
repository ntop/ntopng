--
-- (C) 2017-21 - ntop.org
--
-- Module to keep things in common across pools of various type

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"
local checks = require "checks"
local recipients_mod = require "recipients"
local json = require "dkjson"
local ntop_info = ntop.getInfo()

-- ##############################################

local pools = {}

-- ##############################################

-- A default pool id value associated to any member without pools
pools.DEFAULT_POOL_ID = 0           -- Keep in sync with ntop_defines.h NO_HOST_POOL_ID
pools.DEFAULT_POOL_NAME = "Default" -- Keep in sync with ntop_defines.h DEFAULT_POOL_NAME
pools.DROP_HOST_POOL_NAME = "Jailed hosts pool"

if ntop.isnEdge() then
    -- Compatibility with nEdge pools
    local host_pools_nedge = require "host_pools_nedge"
    pools.DEFAULT_POOL_ID = tonumber(host_pools_nedge.DEFAULT_POOL_ID)
    pools.DEFAULT_POOL_NAME = host_pools_nedge.DEFAULT_POOL_NAME
end

-- ##############################################

-- Possible errors occurring when calling class methods
pools.ERRORS = {
    NO_ERROR = 0,
    GENERIC = -1,
    INVALID_MEMBER = -2,
    ALREADY_BOUND = -3
}

-- ##############################################

-- Limits, in sync with former host_pools_nedge.lua
pools.LIMITED_NUMBER_POOL_MEMBERS = ntop_info["constants.max_num_pool_members"]

-- ##############################################

-- This is the minimum pool id which will be used to create new pools
pools.MIN_ASSIGNED_POOL_ID = 1

-- ##############################################

-- Flag to remember if user bound a recipient to a pool
pools.FIRST_RECIPIENT_BOUND_CACHE_KEY = "ntopng.prefs.endpoint_hints.recipient_has_been_bound"

-- ##############################################

function pools:create(args)
    if args then
        -- We're being sub-classed
        if not args.key then return nil end
    end

    local this = args or {key = "base"}

    setmetatable(this, self)
    self.__index = self

    if args then
        -- Initialization is only run if a subclass is being instanced, that is,
        -- when args is not nil
        this:_initialize()
    end

    return this
end

-- ##############################################

-- @brief Start a pool transaction. Useful to do bulk imports or other operations that may require multiple steps
--        By default, all operations are non-transational, that is, every operation atomically changes the status of pools.
--        To perform multiple, non-atomic operations, a transaction can be started.
--        NOTE: currently, transactions are not supported, unless implemented in pools.lua subclasses
function pools:start_transaction()
end

-- ##############################################

-- @brief Ends a pool transaction.
function pools:end_transaction()
end

-- ##############################################

function pools:_initialize()
    local locked = self:_lock()

    if locked then
        -- Init the default pool, if not already initialized.
        -- The default pool has always empty members and empty recipients
        local default_pool = self:get_pool(pools.DEFAULT_POOL_ID)

        if not default_pool then
	   -- Raw call to persist, no need to go through add_pool as here all the parameters are trusted and
	   -- there's no need to check.
	   -- Default pool is always created with builtin recipients
	   self:_persist(pools.DEFAULT_POOL_ID,
                         pools.DEFAULT_POOL_NAME,
			 {} --[[ no members --]] ,
			 recipients_mod.get_builtin_recipients() --[[ builtin recipients --]], nil --[[ policy ]])
        end

        self:_unlock()
    end
end

-- ##############################################

function pools:_get_pools_prefix_key()
    local key = string.format("ntopng.pools.%s_pools", self.key)
    -- e.g.:
    --  ntopng.pools.interface_pools
    --  ntopng.pools.snmp_device_pools
    --  ntopng.pools.network_pools

    return key
end

-- ##############################################

function pools:_get_pool_ids_key()
    local key = string.format("%s.pool_ids", self:_get_pools_prefix_key())
    -- e.g.:
    --  ntopng.pools.interface_pools.pool_ids

    return key
end

-- ##############################################

function pools:_get_next_pool_id_key()
    local key = string.format("%s.next_pool_id", self:_get_pools_prefix_key())
    -- e.g.:
    --  ntopng.pools.interface_pools.next_pool_id

    return key
end

-- ##############################################

function pools:_get_pool_lock_key()
    local key = string.format("ntopng.cache.pools.%s.pool_lock", self.key)
    -- e.g.:
    --  ntopng.pools.interface_pools.pool_lock

    return key
end

-- ##############################################

function pools:_get_pool_details_key(pool_id)
    if not pool_id then
        -- A pool id is always needed
        return nil
    end

    local key = string.format("%s.pool_id_%d.details",
                              self:_get_pools_prefix_key(), pool_id)

    return key
end

-- ##############################################

function pools:_assign_pool_id()
    local next_pool_id_key = self:_get_next_pool_id_key()

    -- Atomically assign a new pool id
    local next_pool_id = ntop.incrCache(next_pool_id_key)

    -- Make sure the id equals at least the minimum required id
    while next_pool_id < pools.MIN_ASSIGNED_POOL_ID do
        next_pool_id = ntop.incrCache(next_pool_id_key)
    end

    -- Add the atomically assigned pool id to the set of current pool ids (set wants a string)
    ntop.setMembersCache(self:_get_pool_ids_key(),
                         string.format("%d", next_pool_id))

    return next_pool_id
end

-- ##############################################

-- @brief Returns an array with all the currently assigned pool ids
function pools:_get_assigned_pool_ids()
    local res = {pools.DEFAULT_POOL_ID}

    local cur_pool_ids = ntop.getMembersCache(self:_get_pool_ids_key())

    for _, cur_pool_id in pairs(cur_pool_ids) do
        cur_pool_id = tonumber(cur_pool_id)

        if cur_pool_id ~= pools.DEFAULT_POOL_ID then
            -- the default pool id is never returned,
            -- it's a meta-pool without members
            res[#res + 1] = cur_pool_id
        end
    end

    return res
end

-- ##############################################

function pools:_lock()
    local max_lock_duration = 5 -- seconds
    local max_lock_attempts = 5 -- give up after at most this number of attempts
    local lock_key = self:_get_pool_lock_key()

    for i = 1, max_lock_attempts do
        local value_set = ntop.setnxCache(lock_key, "1", max_lock_duration)

        if value_set then
            return true -- lock acquired
        end

        ntop.msleep(1000)
    end

    return false -- lock not acquired
end

-- ##############################################

function pools:_unlock() ntop.delCache(self:_get_pool_lock_key()) end

-- ##############################################

--@brief Method called after a successful execution of method persist
function pools:_post_persist(pool_id, name, members, recipients, policy)
end

-- ##############################################

-- @brief Persist pool details to disk. Possibly assign a pool id
-- @param pool_id The pool_id of the pool which needs to be persisted. If nil, a new pool id is assigned
function pools:_persist(pool_id, name, members, recipients, policy)
    -- self:cleanup()

    -- Default pool name and members cannot be modified
    if pool_id == pools.DEFAULT_POOL_ID then
        name = pools.DEFAULT_POOL_NAME
        members = {}
    end

    local pool_details_key = self:_get_pool_details_key(pool_id)
    local pool_details = {
        name = name,
        members = members,
        recipients = recipients
    }

    ntop.setCache(pool_details_key, json.encode(pool_details))

    self:_post_persist(pool_id, name, members, recipients, policy)

    ntop.reloadPeriodicScripts()

    -- Return the assigned pool_id
    return pool_id
end

-- ##############################################

--- Set a flag to indicate that a pool has been created/edited
function pools:_set_cache_flag()
    if isEmptyString(ntop.getPref(pools.FIRST_RECIPIENT_BOUND_CACHE_KEY)) then
        ntop.setPref(pools.FIRST_RECIPIENT_BOUND_CACHE_KEY, "1")
    end
end

-- ##############################################

-- Create a new pool (unless it already exists)
function pools:add_pool(name, members, recipients, policy)
    local pool_id

    local locked = self:_lock()

    if locked then
        if name and members and recipients then
            local checks_ok = true

            -- Check if duplicate names exist
            local same_name_pool = self:get_pool_by_name(name)
            if same_name_pool then
	      checks_ok = false
            end

            -- Check if members are valid
            if not self:are_valid_members(members) then
                checks_ok = false
            end

            -- Check if members do not belong to any other pool
            if checks_ok then
                for _, member in pairs(members) do
                    local cur_pool = self:get_pool_by_member(member)

                    if cur_pool then
                        -- Member already existing in another pool
                        checks_ok = false
                        break
                    end
                end
            end

            -- Check if recipients are valid
            if checks_ok then
                if not self:are_valid_recipients(recipients) then
                    checks_ok = false
                end
            end

            if checks_ok then
                -- All the checks have succeeded
                -- Now that everything is ok, the id can be assigned and the pool can be persisted with the assigned id
                pool_id = self:_assign_pool_id()
                self:_persist(pool_id, name, members, recipients, policy)
                self:_set_cache_flag()
            end
        end

        self:_unlock()
    end

    return pool_id
end

-- ##############################################

-- Add members and recipients (merge) to an existing pool
function pools:add_to_pool(name, members, recipients)
   local ret = true
   local err = pools.ERRORS.NO_ERROR

   if name then

      local locked = self:_lock()
      if locked then

         -- Check if pool exists
         local pool_details = self:get_pool_by_name(name)
         if pool_details then
            local pool_id = pool_details.pool_id

            -- Add members
            if members then
               for _, member in pairs(members) do
                  local retm, errm = self:bind_member_if_not_already_bound(member, pool_id, true)
	          if not retm then
	             ret = retm
		     err = errm
		  end
	       end
            end

	    -- Add recipients
	    if recipients then
	       for _, recipient_id in pairs(recipients) do
                  -- Check if recipient is valid
                  if self:is_valid_recipient(recipient_id) then
                     local retr, errr = self:_bind_recipient(recipient_id, pool_id)
	             if not retm then
	                ret = retr
		        err = errr
	             end
		  end
               end
	    end
         end

         self:_unlock()
      end
   end

   return ret, err
end

-- ##############################################

-- Overwrite the pool name, members and recipients
-- Policy are used just by Host Pool
function pools:edit_pool(pool_id, new_name, new_members, new_recipients, new_policy)
    local ret = false

    local locked = self:_lock()

    -- Make sure the pool exists
    local cur_pool_details = self:get_pool(pool_id)

    -- If here, pool_id has been found
    if locked then
	
        if cur_pool_details and cur_pool_details.name then 
            local checks_ok = true

            if new_name then
               -- Check if new_name is not the name of any other existing pool
               local same_name_pool = self:get_pool_by_name(new_name)
               if same_name_pool and same_name_pool.pool_id ~= pool_id then
                   checks_ok = false
               end
            else
               new_name = cur_pool_details.name
            end


            if new_members then
               -- Check if members are valid
               if checks_ok and not self:are_valid_members(new_members) then
                  checks_ok = false
               end

               -- Check if none of new_members belongs to any other exsiting pool
               if checks_ok then
                   for _, new_member in pairs(new_members) do
                       local new_member_pool = self:get_pool_by_member(new_member)

                       if new_member_pool and new_member_pool["pool_id"] ~= pool_id then
                           -- Member already existing in another pool
                           checks_ok = false
                           break
                       end
                   end
               end
            else
               -- In case members have not been sumbitted, new_members
               -- are assumed to be the existing members
               new_members = cur_pool_details["members"]
            end

	    if new_recipients then
	       -- Check if recipients are valid
	       if checks_ok and not self:are_valid_recipients(new_recipients) then
		  checks_ok = false
	       end
	    else
	       -- In case recipients have not been sumbitted, new_recipients
	       -- are assumed to be the existing recipients
	       new_recipients = {}

	       -- Populate with recipient IDs
	       for _, recipient in pairs(cur_pool_details["recipients"] or {}) do
		  new_recipients[#new_recipients + 1] = recipient["recipient_id"]
	       end
	    end

            if not new_policy then
               -- In case policy have not been sumbitted, new_policy
               -- is assumed to be the existing policy
	       new_policy = cur_pool_details["policy"] or ""
            end

            if checks_ok then
                -- If here, all checks are valid and the pool can be edited
                self:_persist(pool_id, new_name, new_members, new_recipients, new_policy)
                self:_set_cache_flag()
                -- Pool edited successfully
                ret = true
            end
        end

        self:_unlock()
    end

    return ret
end

-- ##############################################

function pools:delete_pool(pool_id)
    local ret = false

    local locked = self:_lock()

    if locked then
        -- Make sure the pool exists
        local cur_pool_details = self:get_pool(pool_id)

        if cur_pool_details then
            -- Remove the key with all the pool details (e.g., with members)
            ntop.delCache(self:_get_pool_details_key(pool_id))

            -- Remove the pool_id from the set of all currently existing pool ids
            ntop.delMembersCache(self:_get_pool_ids_key(),
                                 string.format("%d", pool_id))

	    -- Reload periodic scripts to make faster refreshes
	    ntop.reloadPeriodicScripts()
            ret = true
        end

        self:_unlock()
    end

    return ret
end

-- ##############################################

-- @brief Returns all the defined pools. Pools are returned in a lua table with pool ids as keys
function pools:get_all_pools()
    local cur_pool_ids = self:_get_assigned_pool_ids()
    local res = {}

    for _, pool_id in pairs(cur_pool_ids) do
        local pool_details = self:get_pool(pool_id)

        if pool_details then res[#res + 1] = pool_details end
    end

    return res
end

-- ##############################################

-- @brief Returns the number of currently defined pool ids
function pools:get_num_pools()
    local cur_pool_ids = self:_get_assigned_pool_ids()

    return #cur_pool_ids
end

-- ##############################################

-- Currently Implemented only into the Host Pools, used to get the host policy
function pools:get_pool_policy(pool_id)
end

-- ##############################################

function pools:get_pool(pool_id, recipient_details)
    local recipient_details = recipient_details or true
    local pool_details
    local pool_details_key = self:_get_pool_details_key(pool_id)

    -- Attempt at retrieving the pool details key and at decoding it from JSON
    if pool_details_key then
        local pool_details_str = ntop.getCache(pool_details_key)
        pool_details = json.decode(pool_details_str)

	if pool_details then
            -- Add the integer pool id
            pool_details["pool_id"] = tonumber(pool_id)

            if pool_details["members"] then
                -- Add a new table with member details
                -- Table keys are members, table values are member details
                pool_details["member_details"] = {}
                for _, member in pairs(pool_details["members"]) do
                    pool_details["member_details"][member] =
                        self:get_member_details(member)
                end
            end

	    if pool_details["recipients"] then
                local recipients = {}
                -- get recipient metadata
                for _, recipient_id in pairs(pool_details["recipients"]) do
		   if tonumber(recipient_id) then -- Handles previously string-keyed recipients
		      local res = {recipient_id = recipient_id}

		      if recipient_details then
			 local recipient = recipients_mod.get_recipient(recipient_id)
			 if recipient and recipient.recipient_name then
			    -- Keep in in sync with overridden method in host_pool.lua
			    res["recipient_name"] = recipient.recipient_name
			    res["recipient_check_categories"] = recipient.check_categories
			    res["recipient_minimum_severity"] = recipient.minimum_severity
			 end
		      end

		      recipients[#recipients + 1] = res
		   end
                end

                pool_details["recipients"] = recipients
            end
        end
    end
    -- Upon success, pool details are returned, otherwise nil
    return pool_details
end

-- ##############################################

function pools:get_pool_by_name(name)
    local cur_pool_ids = self:_get_assigned_pool_ids()

    for _, pool_id in pairs(cur_pool_ids) do
        local pool_details = self:get_pool(pool_id)

        if pool_details and pool_details["name"] and pool_details["name"] ==
            name then
	   return pool_details
        end
    end

    return nil
end

-- ##############################################

-- @brief Returns the pool to which `member` is currently bound to, or nil if `member` is not bound to any pool
function pools:get_pool_by_member(member)
    local assigned_members = self:get_assigned_members()

    if assigned_members[member] then
        return self:get_pool(assigned_members[member]["pool_id"])
    end

    return nil
end

-- ##############################################

-- @brief Returns a flattened table with pool_member->pool_id pairs
function pools:get_assigned_members()
    local cur_pool_ids = self:_get_assigned_pool_ids()
    local res = {}

    for _, pool_id in pairs(cur_pool_ids) do
        local pool_details = self:get_pool(pool_id)

        if pool_details and pool_details["members"] then
            for _, member in pairs(pool_details["members"]) do
                res[member] = {
                    pool_id = tonumber(pool_id),
                    name = pool_details["name"]
                }
            end
        end
    end

    return res
end

-- ##############################################

function pools:get_recipients(pool_id)
    local pool_details
    local res = {}

    if pool_id == nil then return res end

    local locked = self:_lock()

    if locked then

        pool_details = self:get_pool(pool_id)

        self:_unlock()
    end

    if pool_details and pool_details["recipients"] then
        for _, recipient in pairs(pool_details["recipients"]) do
            res[#res + 1] = recipient
        end
    end

    return res
end

-- ##############################################

-- @brief Delete all pools
function pools:cleanup()
    -- Delete pool details
    local cur_pool_ids = self:_get_assigned_pool_ids()
    for _, pool_id in pairs(cur_pool_ids) do
       self:delete_pool(pool_id)
    end

    -- Also delete the default pool - it will be re-created during the next initialization
    self:delete_pool(pools.DEFAULT_POOL_ID)

    local locked = self:_lock()
    if locked then
        -- Delete pool ids
        ntop.delCache(self:_get_pool_ids_key())
        ntop.delCache(self:_get_next_pool_id_key())

        self:_unlock()
    end
end

-- ##############################################

-- @brief Returns a boolean indicating whether the member is a valid pool member
function pools:is_valid_member(member)
    local all_members = self:get_all_members()
    return all_members[member] ~= nil
end

-- ##############################################

-- @brief Returns a boolean indicating whether the array of members passed contains all valid members
function pools:are_valid_members(members)
    for _, member in pairs(members) do
        if not self:is_valid_member(member) then return false end
    end

    return true
end

-- ##############################################

-- @brief Parses recipients submitted via HTTP (validated as `pool_recipients` in `http_lint.lua`) into a table of members
function pools:parse_recipients(recipients_string)
    local recipients = {}

    if isEmptyString(recipients_string) then return recipients end

    -- Unfold the recipients csv
    recipients = recipients_string:split(",") or {recipients_string}

    local res = {}
    for _, recipient_id in pairs(recipients) do
       local recipient_id = tonumber(recipient_id)

       if recipient_id then
	  res[#res + 1] = recipient_id
       end
    end

    return res
end

-- ##############################################

-- @brief Returns available recipient ids which can be added to a pool
function pools:get_available_recipient_ids()
    -- Please note that recipient ids are shared across pools of all types
    -- so all the recipient ids can be returned here without distinction
    local recipients = recipients_mod.get_all_recipients()
    local res = {}

    for _, recipient in pairs(recipients) do
        local recipient_id = recipient.recipient_id
        res[recipient_id] = {
            recipient_id = recipient_id,
            recipient_name = recipient.recipient_name
        }
    end

    return res
end

-- ##############################################

-- @brief Returns a boolean indicating whether the recipient_id is a valid recipient id
function pools:is_valid_recipient(recipient_id)
    local all_recipients = self:get_available_recipient_ids()
    return all_recipients[tonumber(recipient_id)] ~= nil
end

-- ##############################################

-- @brief Returns a boolean indicating whether the array of recipients passed
-- contains all valid recipients
function pools:are_valid_recipients(recipients)
    for _, recipient_id in pairs(recipients) do
        if not self:is_valid_recipient(recipient_id) then return false end
    end

    return true
end

-- ##############################################

-- @brief Unbind a recipient from all pools
function pools:unbind_all_recipient_id(recipient_id)
    if not recipient_id then
        -- Invalid argument
        return
    end

    local locked = self:_lock()
    if locked then
       local all_pools = self:get_all_pools()

        for _, pool in pairs(all_pools) do
            local found = false

            -- New recipients (all pool recipients except for the one being removed)
            local new_recipients = {}

            if pool["recipients"] then
	       for _, cur_recipient in pairs(pool["recipients"]) do
		  if tonumber(cur_recipient.recipient_id) ~= tonumber(recipient_id) then
		     new_recipients[#new_recipients + 1] = tonumber(cur_recipient.recipient_id)
                    else
                        found = true
                    end
                end
            end

            if found then
                -- Rewrite the pool using the new recipients set
                self:_persist(pool["pool_id"], pool["name"], pool["members"], new_recipients, pool["policy"])
            end
        end

        self:_unlock()
    end
end

-- ##############################################

-- @brief Bind a recipient to all pools
function pools:bind_all_recipient_id(recipient_id)
   if not recipient_id then
      -- Invalid argument
      return
   end

   local locked = self:_lock()

   if locked then
      local all_pools = self:get_all_pools()

      for _, pool in pairs(all_pools) do
 	 local found = false

	 -- All the recipients for the current pool
	 local new_recipients = {}

	 if pool["recipients"] then
	    for _, cur_recipient in pairs(pool["recipients"]) do
	       if tonumber(cur_recipient.recipient_id) == tonumber(recipient_id) then
		  -- Already bound for this pool, nothing to do
		  found = true
		  break
	       else
		  -- Prepare a lua array with integer recipient ids
		  new_recipients[#new_recipients + 1] = tonumber(cur_recipient.recipient_id)
	       end
	    end

	    if not found then
	       -- Append the recipient to the array of pool recipients
	       new_recipients[#new_recipients + 1] = tonumber(recipient_id)

	       -- Rewrite the pool using the extended recipients array
	       self:_persist(pool["pool_id"], pool["name"], pool["members"], new_recipients, pool["policy"])
	    end
	 end
      end

      self:_unlock()
   end
end

-- ##############################################

-- @brief Parses members submitted via HTTP (validated as `pool_members` in `http_lint.lua`) into a table of members
function pools:parse_members(members_string)
    local members = {}

    if isEmptyString(members_string) then return members end

    -- Unfold the members csv
    members = members_string:split(",") or {members_string}

    return members
end

-- ##############################################

-- @brief Returns available members which don't already belong to any defined pool
function pools:get_available_members()
    local assigned_members = self:get_assigned_members()
    local all_members = self:get_all_members()

    local res = {}
    for member, member_details in pairs(all_members) do
        --      tprint("checking.."..member)
        --      tprint(member)
        if not assigned_members[member] then res[member] = member_details end
    end

    return res
end

-- ##############################################

-- @brief Bind a recipient to a pool
--        PRIVATE FUNCTION, not to be called outside this class
--        The caller must lock
function pools:_bind_recipient(recipient_id, pool_id)
   local ret, err = false, pools.ERRORS.GENERIC

   -- ASSIGN the recipient to the pool with `pool_id`
   local bind_pool = self:get_pool(pool_id, false)

   if bind_pool then
      -- Members stay the same
      local bind_pool_members = bind_pool["members"]

      -- Recipients are all pool recipients plus the recipient which is being bound
      local bind_pool_recipients = {}
      local already_present = false
      for _, recipient in pairs(bind_pool["recipients"] or {}) do
         bind_pool_recipients[#bind_pool_recipients + 1] = recipient.recipient_id
	 if recipient.recipient_id == recipient_id then
            already_present = true
         end
      end

      if not already_present then
         bind_pool_recipients[#bind_pool_recipients + 1] = recipient_id

      -- Persist the pool with the new `recipient`
         self:_persist(bind_pool["pool_id"], bind_pool["name"],
                       bind_pool_members, bind_pool_recipients, pool["policy"])
      end

      -- Bind has executed successfully
      ret, err = true, pools.ERRORS.NO_ERROR
   end

   return ret, err
end

-- ##############################################

-- @brief Bind a member to a pool
--        PRIVATE FUNCTION, not to be called outside this class
--        The caller must lock and must check the member doesn't belong to
--        any other pool apart from pool_id, before calling
function pools:_bind_member(member, pool_id)
    local ret = false
    local err = pools.ERRORS.GENERIC

    -- ASSIGN the member to the pool with `pool_id`
    -- Note: If the pool_id is pools.DEFAULT_POOL_ID, then `member` is not associated to any pool, it's safe to just return
    if tonumber(pool_id) == pools.DEFAULT_POOL_ID then
        ret = true
	err = pools.ERRORS.NO_ERROR
    else
        local bind_pool = self:get_pool(pool_id, false)

        if bind_pool then
            -- New members are all pool members plus the member which is being bound
            local bind_pool_members = bind_pool["members"]
            bind_pool_members[#bind_pool_members + 1] = member

	    -- Recipients stay the same, but we need to get their ids only
	    local bind_pool_recipients = {}
	    for _, recipient in pairs(bind_pool["recipients"] or {}) do
	       bind_pool_recipients[#bind_pool_recipients + 1] = recipient.recipient_id
	    end

            -- Persist the pool with the new `member`
            self:_persist(bind_pool["pool_id"], bind_pool["name"],
                          bind_pool_members, bind_pool_recipients, bind_pool["policy"])

            -- Bind has executed successfully
            ret = true
	    err = pools.ERRORS.NO_ERROR
        end
    end

    return ret, err
end

-- ##############################################

-- @brief Bind `member` to pool identified with `pool_id`. If the member is already bound to another pool
--        Then the member is first unboud and the bound to `pool_id`.
function pools:bind_member(member, pool_id)
    local ret, err = false, pools.ERRORS.GENERIC

    if not self:is_valid_member(member) then
        return false, pools.ERRORS.INVALID_MEMBER
    end

    local locked = self:_lock()
    if locked then
        -- REMOVE the member if assigned to another pool
        local assigned_members = self:get_assigned_members()
        if assigned_members[member] then
	   local cur_pool = self:get_pool(assigned_members[member]["pool_id"])

	   if cur_pool["pool_id"] == pool_id then
                -- If the current pool id equals the new pool id, there's nothing to do and it is just safe to return
	      ret, err = true, pools.ERRORS.NO_ERROR
	   elseif cur_pool then
	      -- New members are all pool members except for the member which is being removed
	      local new_members = {}
	      for _, cur_member in pairs(cur_pool["members"]) do
		 if cur_member ~= member then
		    new_members[#new_members + 1] = cur_member
		 end
	      end

		-- Recipients stay the same, but we need to get their ids only
		local bind_pool_recipients = {}
		for _, recipient in pairs(cur_pool["recipients"] or {}) do
		   bind_pool_recipients[#bind_pool_recipients + 1] = recipient.recipient_id
		end

                -- Persist the existing pool without the removed `member`
                self:_persist(cur_pool["pool_id"], cur_pool["name"],
                              new_members, bind_pool_recipients, cur_pool["policy"])
            end
        end

        if not ret then ret, err = self:_bind_member(member, pool_id) end

        self:_unlock()
    end

    return ret, err
end

-- ##############################################

-- @brief Bind `member` to pool identified with `pool_id`. If the member is already bound to another pool
--        then nothing is done and an error is returned
function pools:bind_member_if_not_already_bound(member, pool_id, already_locked)
    local ret, err = false, pools.ERRORS.GENERIC

    if not self:is_valid_member(member) then
        return false, pools.ERRORS.INVALID_MEMBER
    end

    local locked = already_locked
    if not locked then
       locked = self:_lock()
    end

    if locked then
        local assigned_members = self:get_assigned_members()
        if assigned_members[member] then
            -- Member already existing
            if assigned_members[member]["pool_id"] == pool_id then
                -- Member is bound to the same pool as the parameter `pool_id`
	       ret, err = true, pools.ERRORS.NO_ERROR
            else
                -- Member is bound to another pool
	       ret, err = false, pools.ERRORS.ALREADY_BOUND
            end
        else
            -- Member isn't bound to any pool, safe to add it
            ret, err = self:_bind_member(member, pool_id)
        end

	if not already_locked then
           self:_unlock()
	end
    end

    return ret, err
end

-- ##############################################

-- @param member a valid pool member
-- @return The pool_id found for `member` or the default pool_id
function pools:get_pool_id(member)
    if not self.assigned_pool_members then
        -- Cache it as class member
        self.assigned_pool_members = self:get_assigned_members()
    end

    if self.assigned_pool_members[member] and
        self.assigned_pool_members[member]["pool_id"] then
        return self.assigned_pool_members[member]["pool_id"]
    end

    return pools.DEFAULT_POOL_ID
end

-- ##############################################

-- @brief Return the name associated to a pool
-- @param pool_id The pool id
-- @return A string with the name of the pool
function pools:get_pool_name(pool_id)
    if pool_id == pools.DEFAULT_POOL_ID then
        return pools.DEFAULT_POOL_NAME
    else
        local pool = self:get_pool(pool_id)

        if pool then return pool["name"] end
    end

    return nil
end

-- ##############################################

-- @brief Returns true for 'dummy' pool instances
--        that don't allow the creations of pools apart from the default one,
--        and also don't allow members to be set/removed.
--        This kind of pools only allow recipients to be added/removed from the
--        default pool.
function pools:default_only()
   -- By default, pool instances are fully fledged, unless this method is
   -- overridden in the subclass.
   return false
end

-- ##############################################

return pools
