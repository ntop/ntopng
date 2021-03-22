--
-- (C) 2017-21 - ntop.org
--
-- Module to keep things in common across control_groups of various type

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

-- ##############################################

local control_groups = {}

-- ##############################################

-- This is the minimum control_group id which will be used to create new control_groups
control_groups.MIN_ASSIGNED_CONTROL_GROUP_ID = 0

-- ##############################################

local function _get_control_groups_prefix_key()
   local key = string.format("ntopng.prefs.control_groups")

   return key
end

-- ##############################################

local function _get_control_group_ids_key()
   local key = string.format("%s.control_group_ids", _get_control_groups_prefix_key())

   return key
end

-- ##############################################

local function _get_control_group_lock_key()
   local key = string.format("ntopng.cache.control_groups.control_group_lock")

   return key
end

-- ##############################################

local function _get_control_group_details_key(control_group_id)
   if not control_group_id then
      -- A control_group id is always needed
      return nil
   end

   local key = string.format("%s.control_group_id_%d.details", _get_control_groups_prefix_key(), control_group_id)

   return key
end

-- ##############################################

-- @brief Returns an array with all the currently assigned control_group ids
local function _get_assigned_control_group_ids()
   local res = {}

   local cur_control_group_ids = ntop.getMembersCache(_get_control_group_ids_key())

   for _, cur_control_group_id in pairs(cur_control_group_ids) do
      cur_control_group_id = tonumber(cur_control_group_id)
      res[#res + 1] = cur_control_group_id
   end

   return res
end

-- ##############################################

local function _assign_control_group_id()
   -- OVERRIDE
   -- To stay consistent with the old implementation control_groups_nedge.lua
   -- control_group_ids are re-used. This means reading the set  of currently used control_group
   -- ids, and chosing the minimum not available control_group id
   -- This method is called from functions which perform locks so
   -- there's no risk to assign the same id multiple times
   local cur_control_group_ids = _get_assigned_control_group_ids()

   local next_control_group_id = control_groups.MIN_ASSIGNED_CONTROL_GROUP_ID

   -- Find the first available control_group id which is not in the set
   for _, control_group_id in pairsByValues(cur_control_group_ids, asc) do
      if control_group_id > next_control_group_id then break end

      next_control_group_id = math.max(control_group_id + 1, next_control_group_id)
   end

   ntop.setMembersCache(_get_control_group_ids_key(), string.format("%d", next_control_group_id))

   return next_control_group_id
end

-- ##############################################

local function _lock()
   local max_lock_duration = 5 -- seconds
   local max_lock_attempts = 5 -- give up after at most this number of attempts
   local lock_key = _get_control_group_lock_key()

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

local function _unlock()
   ntop.delCache(_get_control_group_lock_key())
end

-- ##############################################

-- @brief Persist control_group details to disk. Possibly assign a control_group id
-- @param control_group_id The control_group_id of the control_group which needs to be persisted. If nil, a new control_group id is assigned
local function _persist(control_group_id, name, members, disabled_alerts)
   local control_group_details_key = _get_control_group_details_key(control_group_id)

   local control_group_details = {
      name = name,
      members = members or {},
      disabled_alerts = disabled_alerts or {}
   }

   ntop.setCache(control_group_details_key, json.encode(control_group_details))

   ntop.reloadControlGroups()

   -- Return the assigned control_group_id
   return control_group_id
end

-- ##############################################

function control_groups.add_control_group(name, members)
   local locked = _lock()

   if locked then
      if name and members then
	 local checks_ok = true

	 -- Check if duplicate names exist
	 local same_name_control_group = control_groups.get_control_group_by_name(name)
	 if same_name_control_group then
	    checks_ok = false
	 end

	 -- Check if members are valid
	 if check_ok and not control_groups.are_valid_members(members) then
	    checks_ok = false
	 end

	 if checks_ok then
	    -- All the checks have succeeded
	    -- Now that everything is ok, the id can be assigned and the control_group can be persisted with the assigned id
	    control_group_id = _assign_control_group_id()
	    _persist(control_group_id, name, members)
	 end
      end

      _unlock()
   end

   return control_group_id
end

-- ##############################################

function control_groups.edit_control_group(control_group_id, new_name, new_members)
   local ret = false
   local locked = _lock()

   -- If here, control_group_id has been found
   if locked then
      -- Make sure the control_group exists
      local cur_details = control_groups.get_control_group(control_group_id)

      if cur_details and new_name then
	 local checks_ok = true

	 if not new_members then
	    -- In case members have not been sumbitted, new_members
	    -- are assumed to be the existing members
	    new_members = cur_details["members"]
	 end

	 -- Check if new_name is not the name of any other existing control_group
	 local same_name_control_group = control_groups.get_control_group_by_name(new_name)
	 if same_name_control_group and same_name_control_group.control_group_id ~= control_group_id then
	    checks_ok = false
	 end

	 -- Check if members are valid
	 if checks_ok and not control_groups.are_valid_members(new_members) then
	    checks_ok = false
	 end

	 if checks_ok then
	    -- If here, all checks are valid and the control_group can be edited
	    _persist(control_group_id, new_name, new_members, cur_details["disabled_alerts"])
	    -- Control_Group edited successfully
	    ret = true
	 end
      end

      _unlock()
   end

   return ret
end

-- ##############################################

--@brief Marks an alert as disabled for a given control group identified with `control_group_id`
--@return True, if alert is disabled with success, false otherwise
function control_groups.disable_control_group_flow_alert(control_group_id, alert_key)
   local ret = false
   local locked = _lock()

   -- If here, control_group_id has been found
   if locked then
      -- Make sure the control_group exists
      local cur_details = control_groups.get_control_group(control_group_id)

      if cur_details then
	 local checks_ok = true

	 -- Check if alert_key is already disabled
	 for _, disabled_alert in pairs(cur_details["disabled_alerts"]) do
	    if tonumber(alert_key) == disabled_alert then
	       checks_ok = false -- Already present, nothing to do
	       break
	    end
	 end

	 if checks_ok then
	    -- Disable the alert
	    cur_details["disabled_alerts"][#cur_details["disabled_alerts"] + 1] = tonumber(alert_key)

	    -- If here, all checks are valid and the control_group can be edited
	    _persist(control_group_id, cur_details["name"], cur_details["members"], cur_details["disabled_alerts"])

	    -- Control_Group edited successfully
	    ret = true
	 end
      end

      _unlock()
   end

   return ret
end

-- ##############################################

--@brief Marks an alert as disabled for a given control group identified with `control_group_id`
--@return True, if alert is disabled with success, false otherwise
function control_groups.enable_control_group_flow_alert(control_group_id, alert_key)
   local ret = false
   local locked = _lock()

   -- If here, control_group_id has been found
   if locked then
      -- Make sure the control_group exists
      local cur_details = control_groups.get_control_group(control_group_id)

      if cur_details then
	 local new_disabled_alerts = {}
	 local checks_ok = false

	 -- Check if alert_key is among disabled alerts
	 for _, disabled_alert in pairs(cur_details["disabled_alerts"]) do
	    if tonumber(alert_key) == disabled_alert then
	       checks_ok = true -- Present among the disabled alerts, can remove it
	       -- Don't break, finish the loop to prepare `new_disabled_alerts`
	    else
	       new_disabled_alerts[#new_disabled_alerts + 1] = disabled_alert
	    end
	 end

	 if checks_ok then
	    -- If here, all checks are valid and the control_group can be edited
	    _persist(control_group_id, cur_details["name"], cur_details["members"], new_disabled_alerts)

	    -- Control_Group edited successfully
	    ret = true
	 end
      end

      _unlock()
   end

   return ret
end

-- ##############################################

function control_groups.delete_control_group(control_group_id)
   local ret = false
   local locked = _lock()

   if locked then
      -- Make sure the control_group exists
      local cur_details = control_groups.get_control_group(control_group_id)

      if cur_details then
	 -- Remove the key with all the control_group details (e.g., with members)
	 ntop.delCache(_get_control_group_details_key(control_group_id))

	 -- Remove the control_group_id from the set of all currently existing control_group ids
	 ntop.delMembersCache(_get_control_group_ids_key(), string.format("%d", control_group_id))

	 -- Tell the core to reload control groups
	 ntop.reloadControlGroups()

	 ret = true
      end

      _unlock()
   end

   return ret
end

-- ##############################################

-- @brief Returns all the defined control_groups. Control_Groups are returned in a lua table with control_group ids as keys
function control_groups.get_all_control_groups()
   local cur_control_group_ids = _get_assigned_control_group_ids()
   local res = {}

   for _, control_group_id in pairs(cur_control_group_ids) do
      local control_group_details = control_groups.get_control_group(control_group_id)

      if control_group_details then res[#res + 1] = control_group_details end
   end

   return res
end

-- ##############################################

-- @brief Returns the number of currently defined control_group ids
function control_groups.get_num_control_groups()
   local cur_control_group_ids = _get_assigned_control_group_ids()

   return #cur_control_group_ids
end

-- ##############################################

function control_groups.get_control_group(control_group_id, recipient_details)
   local recipient_details = recipient_details or true
   local control_group_details
   local control_group_details_key = _get_control_group_details_key(control_group_id)

   -- Attempt at retrieving the control_group details key and at decoding it from JSON
   if control_group_details_key then
      local control_group_details_str = ntop.getCache(control_group_details_key)
      control_group_details = json.decode(control_group_details_str)

      if control_group_details then
	 -- Add the integer control_group id
	 control_group_details["control_group_id"] = tonumber(control_group_id)
      end
   end
   -- Upon success, control_group details are returned, otherwise nil
   return control_group_details
end

-- ##############################################

-- @brief Delete all control_groups
function control_groups.cleanup()
   -- Delete control_group details
   local cur_control_group_ids = _get_assigned_control_group_ids()
   for _, control_group_id in pairs(cur_control_group_ids) do
      control_groups.delete_control_group(control_group_id)
   end

   local locked = _lock()
   if locked then
      -- Delete control_group ids
      ntop.delCache(_get_control_group_ids_key())

      _unlock()
   end
end

-- ##############################################

-- @brief Returns a boolean indicating whether the member is a valid control_group member
function control_groups.is_valid_member(member)
   return isIPv4Network(member)
end

-- ##############################################

-- @brief Returns a boolean indicating whether the array of members passed contains all valid members
function control_groups.are_valid_members(members)
   for _, member in pairs(members) do
      if not control_groups.is_valid_member(member) then
	 return false
      end
   end

   return true
end

-- ##############################################

function control_groups.get_control_group_by_name(name)
   local cur_control_group_ids = _get_assigned_control_group_ids()

   for _, control_group_id in pairs(cur_control_group_ids) do
      local control_group_details = control_groups.get_control_group(control_group_id)

      if control_group_details and control_group_details["name"] and control_group_details["name"] == name then
	 return control_group_details
      end
   end

   return nil
end

-- ##############################################

return control_groups
