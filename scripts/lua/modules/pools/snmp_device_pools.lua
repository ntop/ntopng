--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local base_pools = require "base_pools"
local snmp_config = require "snmp_config"
local snmp_cached_dev = require "snmp_cached_dev"

local snmp_device_pools = {}

-- ##############################################

function snmp_device_pools:create()
   -- Instance of the base class
   local _snmp_device_pools = base_pools:create()

   -- Subclass using the base class instance
   self.key = "snmp_device"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _snmp_device_pools_instance = _snmp_device_pools:create(self)

   -- Return the instance
   return _snmp_device_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
function snmp_device_pools:get_member_details(member)
   local cached_device = snmp_cached_dev:create(member)

   local res = {name = member}

   if cached_device and cached_device["system"] and cached_device["system"]["name"] then
      res["name"] = cached_device["system"]["name"]
   end

   return res
end

-- ##############################################

-- @brief Returns a table of all possible snmp_device ids, both assigned and unassigned to pool members
function snmp_device_pools:get_all_members()
   local res = {}

   for snmp_device_ip, _ in pairs(snmp_config.get_all_configured_devices()) do
      -- The key is the member id itself, which in this case is the snmp_device id
      res[snmp_device_ip] = self:get_member_details(snmp_device_ip)
   end

   return res
end

-- ##############################################

return snmp_device_pools
