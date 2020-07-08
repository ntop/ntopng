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

-- interface_pools.get_available_members()

-- TEST interface pools
local s = interface_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_pool', {"5"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == 1)

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

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_second_pool', {"5"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == 2)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_second_pool_edited', {"5"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == 2)

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
assert(new_pool_id == 1)

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
assert(second_pool_id == 2)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_local_network_second_pool_edited', {"127.0.0.0/8"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == 2)

s:cleanup()

-- TEST snmp device pools
local s = snmp_device_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_snmp_device_pool', {"192.168.2.169"} --[[ an array of valid snmp_device ip]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == 1)

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
assert(second_pool_id == 2)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_snmp_device_second_pool_edited', {"192.168.2.169"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == 2)

-- Cleanup
s:cleanup()

-- TEST active monitoring pools
local s = active_monitoring_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_am_pool', {"https@ntop.org"} --[[ an array of valid active monitoring keys ]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == 1)

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
assert(second_pool_id == 2)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_am_second_pool_edited', {"https@ntop.org"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == 2)

-- Cleanup
s:cleanup()


print("OK\n")

