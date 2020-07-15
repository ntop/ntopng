--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end
require "lua_utils"

package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local interface_pools = require "interface_pools"
local local_network_pools = require "local_network_pools"
local snmp_device_pools = require "snmp_device_pools"
local active_monitoring_pools = require "active_monitoring_pools"
local host_pools = require "host_pools"

-- interface_pools.get_available_members()

local function has_member(members, member)
   for _, cur_member in pairs(members) do
      if cur_member == member then
	 return true
      end
   end

   return false
end

-- TEST interface pools
local s = interface_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_pool', {"5"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == s.MIN_ASSIGNED_POOL_ID)

-- Getter (by id)
local pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_pool")

-- Getter (a non-existing id)
assert(not s:get_pool(999))

-- Getter (by name)
pool_details = s:get_pool_by_name('my_pool')
assert(pool_details["name"] == "my_pool")

-- Getter (a non-existing name)
assert(not s:get_pool_by_name('my_non_existing_name'))

-- Edit
s:edit_pool(new_pool_id, 'my_renewed_pool', {"5"}, 0)
pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_renewed_pool")
assert(has_member(pool_details["members"], "5"))

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_second_pool', {"5"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == new_pool_id + 1)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_second_pool_edited', {"5"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == new_pool_id + 1)

-- Assign a memeber to the default pool id and make sure it has been removed from second_pool
s:bind_member("5", s.DEFAULT_POOL_ID)
pool_details = s:get_pool(second_pool_id)
assert(not has_member(pool_details["members"], "5"))

-- Assign back a member to the second pool and make sure second pool contains it
s:bind_member("5", second_pool_id)
pool_details = s:get_pool(second_pool_id)
assert(has_member(pool_details["members"], "5"))

-- Addition of another pool
local third_pool_id = s:add_pool('my_third_pool', {"3"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(third_pool_id == second_pool_id + 1)

-- Attempt at assigning a assigning to a pool a member which is already bound to another pool
local res = s:edit_pool(second_pool_id, 'my_pool', {"3"}, 0)
assert(res == false)

-- 'switch' member from the third to the second pool
s:bind_member("3", second_pool_id)
pool_details = s:get_pool(second_pool_id)
assert(has_member(pool_details["members"], "3"))
pool_details = s:get_pool(third_pool_id)
assert(not has_member(pool_details["members"], "3"))


-- tprint(s:get_all_members())
-- tprint(s:get_available_members())
-- tprint(s:get_assigned_members())
-- tprint(pool_details)
-- tprint(s:get_available_configset_ids())
-- s:delete_pool(new_pool_id)
-- tprint(s:get_all_pools())

-- Cleanup
s:cleanup()

-- TEST local network pools
local s = local_network_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_local_network_pool', {"127.0.0.0/8"} --[[ an array of valid local networks ]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == s.MIN_ASSIGNED_POOL_ID)

-- Getter (by id)
local pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_local_network_pool")

-- Getter (a non-existing id)
assert(not s:get_pool(999))

-- Getter (by name)
pool_details = s:get_pool_by_name('my_local_network_pool')
assert(pool_details["name"] == "my_local_network_pool")

-- Getter (a non-existing name)
assert(not s:get_pool_by_name('my_local_network_non_existing_name'))

-- Edit
s:edit_pool(new_pool_id, 'my_local_network_renewed_pool', {"192.168.2.0/24"}, 0)
pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_local_network_renewed_pool")

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_local_network_second_pool', {"127.0.0.0/8"} --[[ an array of valid local networks ]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == new_pool_id + 1)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_local_network_second_pool_edited', {"127.0.0.0/8"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == new_pool_id + 1)

s:cleanup()

-- TEST snmp device pools
local s = snmp_device_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_snmp_device_pool', {"192.168.2.169"} --[[ an array of valid snmp_device ip]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == s.MIN_ASSIGNED_POOL_ID)

-- Getter (by id)
local pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_snmp_device_pool")

-- Getter (a non-existing id)
assert(not s:get_pool(999))

-- Getter (by name)
pool_details = s:get_pool_by_name('my_snmp_device_pool')
assert(pool_details["name"] == "my_snmp_device_pool")

-- Getter (a non-existing name)
assert(not s:get_pool_by_name('my_snmp_device_non_existing_name'))

-- Edit
s:edit_pool(new_pool_id, 'my_snmp_device_renewed_pool', {"192.168.2.168"}, 0)
pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_snmp_device_renewed_pool")

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_snmp_device_second_pool', {"192.168.2.169"} --[[ an array of valid snmp_device ip ]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == new_pool_id + 1)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_snmp_device_second_pool_edited', {"192.168.2.169"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == new_pool_id + 1)

-- Cleanup
s:cleanup()

-- TEST active monitoring pools
local s = active_monitoring_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_am_pool', {"https@ntop.org"} --[[ an array of valid active monitoring keys ]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == s.MIN_ASSIGNED_POOL_ID)

-- Getter (by id)
local pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_am_pool")

-- Getter (a non-existing id)
assert(not s:get_pool(999))

-- Getter (by name)
pool_details = s:get_pool_by_name('my_am_pool')
assert(pool_details["name"] == "my_am_pool")

-- Getter (a non-existing name)
assert(not s:get_pool_by_name('my_am_non_existing_name'))

-- Edit
s:edit_pool(new_pool_id, 'my_am_renewed_pool', {"icmp@9.9.9.9"}, 0)
pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_am_renewed_pool")

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_am_second_pool', {"https@ntop.org"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == new_pool_id + 1)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_am_second_pool_edited', {"https@ntop.org"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == new_pool_id + 1)

-- Cleanup
s:cleanup()

-- TEST host pools

local s = host_pools:create()

s:cleanup()

-- Creation

local new_pool_id = s:add_pool('my_host_pool', {"192.168.2.222/32@0"} --[[ an array of valid host pool members ]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == s.MIN_ASSIGNED_POOL_ID)

-- Getter (by id)
local pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_host_pool")

-- Getter (a non-existing id)
assert(not s:get_pool(999))

-- Getter (by name)
pool_details = s:get_pool_by_name('my_host_pool')
assert(pool_details["name"] == "my_host_pool")

-- Getter (a non-existing name)
assert(not s:get_pool_by_name('my_host_non_existing_name'))

-- Edit
s:edit_pool(new_pool_id, 'my_host_renewed_pool', {"192.168.2.222/32@0", "192.168.2.0/24@0", "AA:BB:CC:DD:EE:FF"}, 0)
pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_host_renewed_pool")

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_host_second_pool', {"8.8.8.8/32@0"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == new_pool_id)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_host_second_pool_edited', {"192.168.2.0/24@0", "8.8.8.8/32@0"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == new_pool_id)  -- There's no +1 here, host pool ids are re-used

-- Addition of a third pool
local third_pool_id = s:add_pool('my_host_third_pool', {"1.1.1.1/32@0"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(third_pool_id == second_pool_id + 1)

-- Edit of the third pool (try to add a member already bound to another pool)
local res = s:edit_pool(third_pool_id, 'my_host_third_pool_edited', {"8.8.8.8/32@0"}, 0)
assert(res == false)

-- pool_details = s:get_pool(third_pool_id)
-- assert(pool_details["name"] == "my_host_third_pool_edited")  -- There's no +1 here, host pool ids are re-used

-- tprint(s:get_assigned_members())
-- tprint(s:get_available_configset_ids())
-- tprint(s:get_all_pools())

-- Cleanup
s:cleanup()


print("OK\n")

