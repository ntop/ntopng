--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
if ntop.isPro() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

local pools = require "pools"

local host_pool_pools = {}

-- ##############################################

function host_pool_pools:create()
   -- Instance of the base class
   local _host_pool_pools = pools:create()

   -- Subclass using the base class instance
   self.key = "host_pool"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _host_pool_pools_instance = _host_pool_pools:create(self)

   -- Return the instance
   return _host_pool_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
--        POOL WITH NO MEMBERS
function host_pool_pools:get_member_details(member) return {} end

-- ##############################################

-- @brief Returns a table of all possible ids, both assigned and unassigned to pool members
--        POOL WITH NO MEMBERS
function host_pool_pools:get_all_members() return {} end

-- ##############################################

function host_pool_pools:default_only()
   -- This is a dummy, default-only pool
   return true
end

-- ##############################################

return host_pool_pools
